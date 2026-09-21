import SwiftData
import SwiftUI

struct JobFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]

    var job: Job?
    var lockedClient: Client?
    var onSave: (Job) -> Void = { _ in }

    @State private var title = ""
    @State private var selectedClientID: PersistentIdentifier?
    @State private var status: JobStatus = .scheduled
    @State private var scheduledAt = Date.now
    @State private var address = ""
    @State private var notes = ""
    @State private var didLoad = false

    private var selectedClient: Client? {
        if let lockedClient { return lockedClient }
        return clients.first { $0.persistentModelID == selectedClientID }
    }

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && selectedClient != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Job") {
                    TextField("Title", text: $title)
                    Picker("Status", selection: $status) {
                        ForEach(JobStatus.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    DatePicker("When", selection: $scheduledAt)
                }
                Section("Client") {
                    if clients.isEmpty {
                        Text("Add a client before creating a job.")
                            .foregroundStyle(.secondary)
                    } else if lockedClient != nil {
                        Text(lockedClient?.name ?? "")
                    } else {
                        Picker("Client", selection: $selectedClientID) {
                            Text("Select").tag(nil as PersistentIdentifier?)
                            ForEach(clients) { client in
                                Text(client.name).tag(client.persistentModelID as PersistentIdentifier?)
                            }
                        }
                        .onChange(of: selectedClientID) { _, _ in
                            if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                address = selectedClient?.address ?? ""
                            }
                        }
                    }
                    TextField("Job address", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Notes") {
                    TextField("What you saw on site", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(job == nil ? "New Job" : "Edit Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(canSave == false)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard didLoad == false else { return }
        didLoad = true
        if let job {
            title = job.title
            status = job.status
            scheduledAt = job.scheduledAt
            address = job.address
            notes = job.notes
            selectedClientID = job.client?.persistentModelID
        } else if let lockedClient {
            selectedClientID = lockedClient.persistentModelID
            address = lockedClient.address
            scheduledAt = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        } else if let first = clients.first {
            selectedClientID = first.persistentModelID
            address = first.address
        }
    }

    private func save() {
        guard let client = selectedClient else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAddress = trimmedAddress.isEmpty ? client.address : trimmedAddress

        let saved: Job
        if let job {
            job.title = trimmedTitle
            job.status = status
            job.scheduledAt = scheduledAt
            job.address = resolvedAddress
            job.notes = trimmedNotes
            job.client = client
            job.needsSync = true
            saved = job
        } else {
            let newJob = Job(
                title: trimmedTitle,
                status: status,
                scheduledAt: scheduledAt,
                address: resolvedAddress,
                notes: trimmedNotes,
                needsSync: true
            )
            context.insert(newJob)
            newJob.client = client
            saved = newJob
        }
        try? context.save()
        onSave(saved)
        dismiss()
    }
}
