import FamilyControls
import SwiftUI

struct BlockListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = BlockConfig()
    @State private var showBlockedPicker = false
    @State private var showAllowedPicker = false

    var body: some View {
        NavigationStack {
            Form {
                if model.isFocusing {
                    Section {
                        Label("Locked while you're focusing. End the session with your desk tag to make changes.",
                              systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Picker("Block", selection: $draft.mode) {
                        ForEach(BlockMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(draft.mode == .selected
                         ? "Only the apps and categories you pick are blocked."
                         : "Every app is blocked except the ones on your allowlist. Phone and Settings always stay available.")
                }

                if draft.mode == .selected {
                    Section {
                        Button("Choose apps to block") { showBlockedPicker = true }
                        summary(draft.blocked)
                        TokenList(tokens: draft.blocked.applicationTokens)
                    } header: {
                        Text("Blocked")
                    } footer: {
                        if draft.blocked.applicationTokens.count > BlockConfig.maxAppTokens {
                            Text("iOS can block at most \(BlockConfig.maxAppTokens) individual apps. Block a whole category instead.")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button("Choose always-allowed apps") { showAllowedPicker = true }
                    TokenList(tokens: draft.allowed.applicationTokens)
                } header: {
                    Text("Always allowed")
                } footer: {
                    Text("These apps are never blocked, even if their category is. Good for Maps, banking, 2FA and music.")
                }

                Section {
                    Toggle("Prevent deleting apps during a session", isOn: $draft.preventAppRemoval)
                } footer: {
                    Text("Stops you from deleting Tawfeeq (or any app) to escape a session.")
                }
            }
            .disabled(model.isFocusing)
            .navigationTitle("Block list")
            .familyActivityPicker(isPresented: $showBlockedPicker, selection: $draft.blocked)
            .familyActivityPicker(isPresented: $showAllowedPicker, selection: $draft.allowed)
            .onAppear { draft = model.config }
            .onChange(of: model.config) { _, newValue in draft = newValue }
            .onChange(of: draft) { _, newValue in
                if !model.updateConfig(newValue) { draft = model.config }
            }
        }
    }

    @ViewBuilder
    private func summary(_ selection: FamilyActivitySelection) -> some View {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        if apps + categories + sites > 0 {
            Text("\(apps) apps · \(categories) categories · \(sites) websites")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Shows app names and icons for opaque Screen Time tokens.
private struct TokenList: View {
    let tokens: Set<ApplicationToken>

    var body: some View {
        ForEach(Array(tokens), id: \.self) { token in
            Label(token)
        }
    }
}
