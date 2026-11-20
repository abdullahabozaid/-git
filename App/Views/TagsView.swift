import SwiftUI

struct TagsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showEnroll = false

    var body: some View {
        NavigationStack {
            List {
                if model.tags.isEmpty {
                    ContentUnavailableView(
                        "No tags yet",
                        systemImage: "wave.3.right",
                        description: Text("Add the NFC sticker on your desk. You can add a spare one to keep somewhere else as a backup.")
                    )
                }

                ForEach(model.tags) { tag in
                    HStack(spacing: 12) {
                        Image(systemName: tag.role.symbol)
                            .frame(width: 28)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tag.name).font(.body.weight(.medium))
                            Text(tag.role.label + (tag.hasLink ? "" : " · ID only"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        if !model.isFocusing {
                            Button("Remove", role: .destructive) { model.removeTag(tag) }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
            .toolbar {
                Button {
                    showEnroll = true
                } label: {
                    Label("Add tag", systemImage: "plus")
                }
                .disabled(model.isFocusing || model.isScanning)
            }
            .sheet(isPresented: $showEnroll) {
                EnrollTagSheet()
                    .presentationDetents([.medium])
            }
        }
    }
}

private struct EnrollTagSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role: TagRole = .desk

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Desk)", text: $name)
                    Picker("Role", selection: $role) {
                        ForEach(TagRole.allCases) { Text($0.label).tag($0) }
                    }
                } footer: {
                    Text("You'll tap the tag twice: once to read it, once to confirm and write Tawfeeq's link onto it.")
                }
            }
            .navigationTitle("Add tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Scan") {
                        let name = name, role = role
                        dismiss()
                        Task { await model.enrollTag(name: name, role: role) }
                    }
                }
            }
        }
    }
}
