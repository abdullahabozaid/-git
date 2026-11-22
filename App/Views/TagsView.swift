import SwiftUI

struct TagsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showEnroll = false

    var body: some View {
        List {
            if model.tags.isEmpty {
                ContentUnavailableView(
                    "No tags yet",
                    systemImage: "wave.3.right",
                    description: Text("Add the NFC sticker on your desk. You can add a spare one to keep somewhere else as a backup.")
                )
            }

            ForEach(TagRole.allCases) { role in
                let tags = model.tags.filter { $0.role == role }
                if !tags.isEmpty {
                    Section {
                        ForEach(tags) { tag in
                            TagRow(tag: tag)
                                .swipeActions {
                                    if !model.isFocusing {
                                        Button("Remove", role: .destructive) { model.removeTag(tag) }
                                    }
                                }
                        }
                    } header: {
                        Text(role == .desk ? "Desk" : "Spare")
                    } footer: {
                        Text(role == .desk
                             ? "Starts and ends sessions, and checks you in each morning."
                             : "Ends a session if your desk tag goes missing. Keep it away from your desk.")
                    }
                }
            }

            if !model.tags.contains(where: { $0.role == .spare }), !model.tags.isEmpty {
                Section {
                    Button {
                        showEnroll = true
                    } label: {
                        Label("Add a spare tag", systemImage: "key.fill")
                    }
                } footer: {
                    Text("Recommended. A spare in a drawer means a lost desk tag never locks you out.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
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
            EnrollTagSheet(defaultRole: model.tags.contains { $0.role == .desk } ? .spare : .desk)
                .presentationDetents([.medium])
        }
    }
}

private struct TagRow: View {
    let tag: EnrolledTag

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tag.role.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tag.role == .desk ? Theme.focus : Theme.gold))
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name).font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        var parts: [String] = []
        if let last = tag.lastScannedAt {
            parts.append("Last scanned \(last.formatted(.relative(presentation: .named)))")
        } else {
            parts.append("Added \(tag.enrolledAt.formatted(date: .abbreviated, time: .omitted))")
        }
        if !tag.hasLink { parts.append("ID only") }
        return parts.joined(separator: " · ")
    }
}

private struct EnrollTagSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role: TagRole

    init(defaultRole: TagRole) {
        _role = State(initialValue: defaultRole)
        _name = State(initialValue: defaultRole == .desk ? "Desk" : "Drawer")
    }

    private var suggestions: [String] {
        role == .desk ? ["Desk", "Study", "Office", "Kitchen"] : ["Drawer", "Bag", "Car", "Wallet"]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Role", selection: $role) {
                        ForEach(TagRole.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    // Recognition over recall: pick a name, typing is optional.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                let selected = name == suggestion
                                Button(suggestion) { name = suggestion }
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(selected ? Color.white : Theme.text)
                                    .background(Capsule().fill(selected ? Theme.focus : Theme.secondaryText.opacity(0.12)))
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    TextField("Or type a name", text: $name)
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
