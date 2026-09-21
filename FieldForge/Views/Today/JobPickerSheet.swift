import SwiftData
import SwiftUI

struct JobPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Job.scheduledAt, order: .reverse) private var jobs: [Job]
    var onPick: (Job) -> Void

    @State private var showNewJob = false
    @State private var createdJob: Job?

    var body: some View {
        NavigationStack {
            Group {
                if jobs.isEmpty {
                    EmptyHint(
                        title: "No jobs yet",
                        message: "Create the job first, then add line items from the price book.",
                        systemImage: "wrench.and.screwdriver",
                        actionTitle: "New job",
                        action: { showNewJob = true }
                    )
                } else {
                    List(jobs) { job in
                        Button {
                            onPick(job)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(job.title)
                                    .font(ForgeType.rowTitle)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Text(job.client?.name ?? "No client")
                                    .font(ForgeType.secondary)
                                    .foregroundStyle(.secondary)
                                StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
                            }
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("New Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("New job") { showNewJob = true }
                }
            }
            .sheet(isPresented: $showNewJob, onDismiss: finishCreatedJob) {
                JobFormView(job: nil) { job in
                    createdJob = job
                }
            }
        }
    }

    private func finishCreatedJob() {
        guard let createdJob else { return }
        onPick(createdJob)
        self.createdJob = nil
        dismiss()
    }
}
