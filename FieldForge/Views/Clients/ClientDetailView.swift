import SwiftData
import SwiftUI

struct ClientDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var client: Client
    @State private var showEdit = false
    @State private var showNewJob = false
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    private var jobs: [Job] {
        client.jobs.sorted { $0.scheduledAt > $1.scheduledAt }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(client.name)
                        .font(.title2.weight(.bold))
                    Text(client.address)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                contactRow(symbol: "phone.fill", text: client.phone)
                contactRow(symbol: "envelope.fill", text: client.email)
            }
            if client.notes.isEmpty == false {
                Section("Notes") {
                    Text(client.notes)
                        .font(.body)
                }
            }
            Section {
                if jobs.isEmpty {
                    Text("No jobs for this client yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(jobs) { job in
                        NavigationLink(value: job) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(job.title)
                                    .font(.body.weight(.semibold))
                                HStack {
                                    Text(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                Button {
                    showNewJob = true
                } label: {
                    Label("New job for \(client.name)", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            } header: {
                Text("Jobs")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Client")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete client")
            }
        }
        .sheet(isPresented: $showEdit) {
            ClientFormView(client: client)
        }
        .sheet(isPresented: $showNewJob) {
            JobFormView(job: nil, lockedClient: client)
        }
        .confirmationDialog(
            "Delete \(client.name)?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete client and jobs", role: .destructive) {
                context.delete(client)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their jobs, quotes, and invoices on this iPhone are removed with them.")
        }
    }

    private func contactRow(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.body)
            .frame(minHeight: 36, alignment: .leading)
    }
}
