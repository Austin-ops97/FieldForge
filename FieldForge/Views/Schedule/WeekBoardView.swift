import SwiftData
import SwiftUI

struct WeekBoardView: View {
    @Query(sort: \Job.scheduledAt) private var jobs: [Job]
    @State private var anchor = Date.now

    private var calendar: Calendar { Calendar.current }

    private var weekStart: Date {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: anchor)
    }

    private var days: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        let grouped = jobsByDay
        List {
            Section {
                Text(rangeTitle)
                    .font(ForgeType.section)
                Text("Every job scheduled this week, including finished ones.")
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
            }
            ForEach(days, id: \.self) { day in
                let dayJobs = grouped[calendar.startOfDay(for: day)] ?? []
                Section {
                    if dayJobs.isEmpty {
                        Text("Nothing scheduled")
                            .font(ForgeType.secondary)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    } else {
                        ForEach(dayJobs) { job in
                            NavigationLink(value: job.forgeRoute) {
                                WeekJobRow(job: job)
                            }
                        }
                    }
                } header: {
                    Text(dayTitle(day))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Week")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    shiftWeek(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous week")
                Button {
                    shiftWeek(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next week")
            }
        }
    }

    private var rangeTitle: String {
        guard let end = days.last else { return "This week" }
        let startText = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(startText) – \(endText)"
    }

    private func dayTitle(_ day: Date) -> String {
        let name = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if calendar.isDateInToday(day) { return "\(name) · Today" }
        return name
    }

    private var jobsByDay: [Date: [Job]] {
        let start = weekStart
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [:] }
        var grouped: [Date: [Job]] = [:]
        for job in jobs where job.scheduledAt >= start && job.scheduledAt < end {
            let day = calendar.startOfDay(for: job.scheduledAt)
            grouped[day, default: []].append(job)
        }
        return grouped
    }

    private func shiftWeek(_ value: Int) {
        anchor = calendar.date(byAdding: .day, value: value * 7, to: weekStart) ?? anchor
    }
}

private struct WeekJobRow: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(job.scheduledAt.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(ForgeTheme.ink)
                    .frame(width: 88, alignment: .leading)
                Text(job.title)
                    .font(ForgeType.rowTitle)
                    .lineLimit(2)
            }
            Text(job.client?.name ?? "No client")
                .font(ForgeType.secondary)
                .foregroundStyle(.secondary)
                .padding(.leading, 88)
            StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
                .padding(.leading, 88)
        }
        .padding(.vertical, 4)
    }
}
