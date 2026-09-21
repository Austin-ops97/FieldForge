import SwiftData
import SwiftUI

struct JobsListView: View {
    @Query(sort: \Job.scheduledAt, order: .reverse) private var jobs: [Job]
    @State private var path = NavigationPath()
    @State private var search = ""
    @State private var statusFilter: JobStatus?
    @State private var showNew = false
    @State private var pendingJob: Job?

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
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                filterBar
                Group {
                    if filtered.isEmpty {
                        EmptyHint(
                            title: jobs.isEmpty ? "No jobs yet" : "Nothing in this view",
                            message: jobs.isEmpty
                                ? "Create a job with a client, address, and time."
                                : "Nothing matches this filter.",
                            systemImage: "wrench.and.screwdriver",
                            actionTitle: jobs.isEmpty ? "New job" : "Clear filters",
                            action: {
                                if jobs.isEmpty {
                                    showNew = true
                                } else {
                                    statusFilter = nil
                                    search = ""
                                }
                            }
                        )
                    } else {
                        List(filtered) { job in
                            NavigationLink(value: job.forgeRoute) {
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        GlobalSearchView()
                    } label: {
                        Image(systemName: "text.magnifyingglass")
                    }
                    .accessibilityLabel("Search all")
                    NavigationLink {
                        WeekBoardView()
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Week")
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Job")
                }
            }
            .forgeRoutes()
            .sheet(isPresented: $showNew, onDismiss: openPendingJob) {
                JobFormView(job: nil) { job in
                    pendingJob = job
                }
            }
        }
    }

    private func openPendingJob() {
        guard let pendingJob else { return }
        path.append(pendingJob.forgeRoute)
        self.pendingJob = nil
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", selected: statusFilter == nil, tint: ForgeTheme.ink) {
                    statusFilter = nil
                }
                ForEach(JobStatus.allCases) { status in
                    FilterChip(title: status.label, selected: statusFilter == status, tint: ForgeTheme.ink) {
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(job.title)
                    .font(ForgeType.rowTitle)
                    .lineLimit(2)
            }
            Text(job.client?.name ?? "No client")
                .font(ForgeType.secondary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                .font(ForgeType.caption)
                .foregroundStyle(.secondary)
            StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
        }
        .padding(.vertical, 6)
    }
}
