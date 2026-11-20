import CoreNFC
import Foundation

struct ScanResult: Equatable, Sendable {
    /// Hardware UID, lowercase hex.
    let uid: String
    /// First URI record on the tag, if any.
    let ndefURL: URL?
    /// Set when a write was requested and succeeded.
    var wroteURL = false
}

enum ScanError: LocalizedError, Equatable {
    case unavailable
    case cancelled
    case busy
    case rejected(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: "This iPhone can't read NFC tags."
        case .cancelled: "Scan cancelled."
        case .busy: "A scan is already in progress."
        case .rejected(let message), .failed(let message): message
        }
    }
}

/// Wraps NFCTagReaderSession in async/await.
///
/// We use the *tag* reader (not the NDEF reader) because it gives us the hardware UID,
/// and NTAG stickers show up as `.miFare`, which also supports reading/writing NDEF.
/// All delegate callbacks run on the main queue, so state is only touched there.
final class TagScanner: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
    /// Return nil to accept the tag, or a message to reject it (shown in the scan sheet).
    typealias Validator = @Sendable (ScanResult) -> String?

    private enum Mode {
        case read
        case write(URL)
    }

    private var session: NFCTagReaderSession?
    private var mode: Mode = .read
    private var validate: Validator = { _ in nil }
    private var continuation: CheckedContinuation<ScanResult, Error>?

    func read(prompt: String, validate: @escaping Validator = { _ in nil }) async throws -> ScanResult {
        try await begin(mode: .read, prompt: prompt, validate: validate)
    }

    /// Reads the UID, runs `validate`, then writes `url` as an NDEF URI record if the tag is writable.
    /// If the tag can't be written, the scan still succeeds with `wroteURL == false`.
    func write(url: URL, prompt: String, validate: @escaping Validator = { _ in nil }) async throws -> ScanResult {
        try await begin(mode: .write(url), prompt: prompt, validate: validate)
    }

    private func begin(mode: Mode, prompt: String, validate: @escaping Validator) async throws -> ScanResult {
        guard NFCTagReaderSession.readingAvailable else { throw ScanError.unavailable }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                guard self.continuation == nil else {
                    continuation.resume(throwing: ScanError.busy)
                    return
                }
                guard let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: .main) else {
                    continuation.resume(throwing: ScanError.unavailable)
                    return
                }
                self.continuation = continuation
                self.mode = mode
                self.validate = validate
                self.session = session
                session.alertMessage = prompt
                session.begin()
            }
        }
    }

    // MARK: - Completion

    private func finish(_ result: Result<ScanResult, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    private func succeed(_ session: NFCTagReaderSession, _ result: ScanResult) {
        session.alertMessage = "Done"
        finish(.success(result))
        session.invalidate()
    }

    private func fail(_ session: NFCTagReaderSession, _ message: String) {
        finish(.failure(ScanError.rejected(message)))
        session.invalidate(errorMessage: message)
    }

    // MARK: - NFCTagReaderSessionDelegate

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        switch (error as? NFCReaderError)?.code {
        case .readerSessionInvalidationErrorUserCanceled:
            finish(.failure(ScanError.cancelled))
        case .readerSessionInvalidationErrorSessionTimeout:
            finish(.failure(ScanError.failed("Scan timed out. Try again.")))
        default:
            finish(.failure(ScanError.failed(error.localizedDescription)))
        }
        self.session = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "More than one tag found. Hold near just one."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { session.restartPolling() }
            return
        }
        guard case let .miFare(miFare) = tag else {
            fail(session, "This card type isn't supported. Use an NTAG sticker or card.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.fail(session, "Couldn't connect to the tag. Hold still and try again.")
                return
            }

            let uid = miFare.identifier.map { String(format: "%02x", $0) }.joined()

            miFare.queryNDEFStatus { status, _, statusError in
                let canUseNDEF = statusError == nil && status != .notSupported

                let handleURL: (URL?) -> Void = { url in
                    let result = ScanResult(uid: uid, ndefURL: url)
                    if let problem = self.validate(result) {
                        self.fail(session, problem)
                        return
                    }
                    switch self.mode {
                    case .read:
                        self.succeed(session, result)
                    case .write(let target):
                        guard status == .readWrite,
                              let record = NFCNDEFPayload.wellKnownTypeURIPayload(url: target) else {
                            // Locked or unformatted tag: enroll by UID only.
                            self.succeed(session, result)
                            return
                        }
                        miFare.writeNDEF(NFCNDEFMessage(records: [record])) { writeError in
                            var written = result
                            written.wroteURL = writeError == nil
                            self.succeed(session, written)
                        }
                    }
                }

                guard canUseNDEF else {
                    handleURL(nil)
                    return
                }
                miFare.readNDEF { message, _ in
                    handleURL(message?.records.lazy.compactMap { $0.wellKnownTypeURIPayload() }.first)
                }
            }
        }
    }
}
