import SwiftData
import SwiftUI

struct ClientDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var client: Client
    @State private var showEdit = false
    @State private var showNewJob = false
    @State private var confirmDelete = false
    @State private var createdJob: Job?
    @State private var showCreatedJob = false
    @State private var savedJobThisSession = false
    @Environment(\.dismiss) private var dismiss

    private var jobs: [Job] {
        client.jobs.sorted { $0.scheduledAt > $1.scheduledAt }
    }

    private var openJobCount: Int {
        jobs.filter { $0.status != .done }.count
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(client.name)
                        .font(ForgeType.section)
                    Text(client.address)
                        .font(ForgeType.secondary)
                        .foregroundStyle(.secondary)
                    HStack(spacing: ForgeTheme.Space.s) {
                        metric(title: "Jobs", value: "\(jobs.count)")
                        metric(title: "Open", value: "\(openJobCount)")
                    }
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
                        NavigationLink(value: job.forgeRoute) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(job.title)
                                    .font(ForgeType.rowTitle)
                                    .lineLimit(2)
                                Text(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(ForgeType.secondary)
                                    .foregroundStyle(.secondary)
                                StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
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
        .sheet(isPresented: $showNewJob, onDismiss: {
            if savedJobThisSession {
                showCreatedJob = true
            }
            savedJobThisSession = false
        }) {
            JobFormView(job: nil, lockedClient: client) { job in
                createdJob = job
                savedJobThisSession = true
            }
        }
        .navigationDestination(isPresented: $showCreatedJob) {
            if let createdJob {
                JobDetailView(job: createdJob)
            }
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

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(ForgeType.overline)
                .foregroundStyle(.secondary)
                .tracking(0.4)
            Text(value)
                .font(ForgeType.money)
                .foregroundStyle(ForgeTheme.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private func contactRow(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.body)
            .frame(minHeight: 36, alignment: .leading)
    }
}
