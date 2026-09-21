import SwiftData
import SwiftUI

struct JobPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Job.scheduledAt, order: .reverse) private var jobs: [Job]
    var onPick: (Job) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if jobs.isEmpty {
                    EmptyHint(
                        title: "No jobs yet",
                        message: "Create a job first, then build a quote from it.",
                        systemImage: "wrench.and.screwdriver"
                    )
                } else {
                    List(jobs) { job in
                        Button {
                            onPick(job)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(job.client?.name ?? "No client")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Quote for which job?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
