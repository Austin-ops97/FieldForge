import SwiftData
import SwiftUI

struct JobsListView: View {
    @Query(sort: \Job.scheduledAt, order: .reverse) private var jobs: [Job]
    @State private var search = ""
    @State private var statusFilter: JobStatus?
    @State private var showNew = false

    private var filtered: [Job] {
        jobs.filter { job in
            let matchesStatus = statusFilter == nil || job.status == statusFilter
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard query.isEmpty == false else { return matchesStatus }
            let haystack = [job.title, job.client?.name ?? "", job.address].joined(separator: " ")
            return matchesStatus && haystack.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Group {
                    if filtered.isEmpty {
                        EmptyHint(
                            title: jobs.isEmpty ? "No jobs yet" : "Nothing in this view",
                            message: jobs.isEmpty
                                ? "Start a job from Today or from a client."
                                : "Clear the filter or try another search.",
                            systemImage: "wrench.and.screwdriver"
                        )
                    } else {
                        List(filtered) { job in
                            NavigationLink(value: job) {
                                JobListRow(job: job)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Jobs")
            .searchable(text: $search, prompt: "Title, client, or street")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New job")
                }
            }
            .forgeRoutes()
            .sheet(isPresented: $showNew) {
                JobFormView(job: nil)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", selected: statusFilter == nil) {
                    statusFilter = nil
                }
                ForEach(JobStatus.allCases) { status in
                    FilterChip(title: status.label, selected: statusFilter == status) {
                        statusFilter = status
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct JobListRow: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.title)
                    .font(.body.weight(.semibold))
                if job.needsSync { SyncBadge() }
                Spacer()
                StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
            }
            Text(job.client?.name ?? "No client")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
