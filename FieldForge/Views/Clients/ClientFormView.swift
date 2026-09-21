import SwiftData
import SwiftUI

struct ClientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var client: Client?
    var onSave: (Client) -> Void = { _ in }

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""

    private var canSave: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $name)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Notes") {
                    TextField("Gate codes, pets, how to reach them", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(client == nil ? "New Client" : "Edit Client")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                FormSaveBar(enabled: canSave, action: save)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let client else { return }
        name = client.name
        phone = client.phone
        email = client.email
        address = client.address
        notes = client.notes
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved: Client
        if let client {
            client.name = trimmedName
            client.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            client.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
            client.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
            client.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            client.needsSync = true
            saved = client
        } else {
            let newClient = Client(
                name: trimmedName,
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                address: address.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                needsSync: true
            )
            context.insert(newClient)
            saved = newClient
        }
        try? context.save()
        onSave(saved)
        dismiss()
    }
}
