import SwiftData
import SwiftUI

struct JobDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var job: Job

    @State private var showEdit = false
    @State private var selectedPhoto: JobPhoto?
    @State private var showVoice = false
    @State private var quoteToOpen: Quote?
    @State private var showNewQuote = false

    private var photos: [JobPhoto] {
        job.photos.sorted { $0.createdAt < $1.createdAt }
    }

    private var quotes: [Quote] {
        job.quotes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.title)
                        .font(ForgeType.section)
                    Text(job.scheduledAt.formatted(date: .complete, time: .shortened))
                        .font(ForgeType.secondary)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                ChipFlow(spacing: 8) {
                    ForEach(JobStatus.allCases) { status in
                        FilterChip(title: status.label, selected: job.status == status, tint: ForgeTheme.jobTint(status)) {
                            job.status = status
                            job.needsSync = true
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Client") {
                if let client = job.client {
                    NavigationLink(value: client.forgeRoute) {
                        Label(client.name, systemImage: "person.fill")
                            .font(.body.weight(.semibold))
                            .frame(minHeight: 36, alignment: .leading)
                    }
                } else {
                    Text("No client linked")
                        .foregroundStyle(.secondary)
                }
                Label(job.address, systemImage: "mappin.and.ellipse")
                    .font(.body)
            }

            Section("Notes") {
                Text(job.notes.isEmpty ? "No notes yet. Edit the job to add them." : job.notes)
                    .font(.body)
                    .foregroundStyle(job.notes.isEmpty ? .secondary : .primary)
            }

            Section("Photos") {
                if photos.isEmpty {
                    Text("No photos yet. These are placeholders until the camera lands.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photos) { photo in
                                Button {
                                    selectedPhoto = photo
                                } label: {
                                    PhotoCard(photo: photo)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 120)
                }
                Button {
                    addPhotoPlaceholder()
                } label: {
                    Label("Add photo placeholder", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }

            Section("Voice note") {
                Button {
                    if job.voiceMemoCaption.isEmpty {
                        job.voiceMemoCaption = "0:12 · note saved on this iPhone"
                        job.needsSync = true
                    }
                    showVoice = true
                } label: {
                    Label(
                        job.voiceMemoCaption.isEmpty ? "Save a voice-note stub" : job.voiceMemoCaption,
                        systemImage: "mic.fill"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }

            Section("Quotes") {
                if quotes.isEmpty {
                    Text("No quote yet. Create one and add prices below.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(quotes) { quote in
                        NavigationLink(value: quote.forgeRoute) {
                            QuoteSummaryRow(quote: quote)
                        }
                    }
                    ForEach(quotes.compactMap { $0.invoice }) { invoice in
                        NavigationLink(value: invoice.forgeRoute) {
                            HStack {
                                Label(invoice.number, systemImage: "dollarsign.circle")
                                    .font(.body.weight(.semibold))
                                Spacer()
                                StatusChip(
                                    title: invoice.displayStatus.label,
                                    tint: ForgeTheme.invoiceTint(invoice.displayStatus)
                                )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Button {
                    quoteToOpen = QuoteActions.makeDraft(for: job, in: context)
                    showNewQuote = true
                } label: {
                    Label("Create quote", systemImage: "doc.badge.plus")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Job")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            JobFormView(job: job)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoPlaceholderSheet(photo: photo)
        }
        .sheet(isPresented: $showVoice) {
            VoiceNoteSheet(caption: job.voiceMemoCaption)
        }
        .navigationDestination(isPresented: $showNewQuote) {
            if let quoteToOpen {
                QuoteBuilderView(quote: quoteToOpen)
            }
        }
    }

    private func addPhotoPlaceholder() {
        let symbols = ["camera.fill", "drop.fill", "wrench.fill", "photo.fill"]
        let photo = JobPhoto(
            caption: "Site photo \(photos.count + 1)",
            symbolName: symbols[photos.count % symbols.count]
        )
        context.insert(photo)
        photo.job = job
        job.needsSync = true
        try? context.save()
    }
}

private struct PhotoCard: View {
    let photo: JobPhoto

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: photo.symbolName)
                .font(.title2)
                .foregroundStyle(ForgeTheme.ink)
            Text(photo.caption)
                .font(ForgeType.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 132, height: 112)
        .forgeCard()
    }
}

private struct PhotoPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let photo: JobPhoto

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: photo.symbolName)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(ForgeTheme.ink)
                    .frame(width: 160, height: 160)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: ForgeTheme.Radius.l, style: .continuous))
                Text(photo.caption)
                    .font(.title3.weight(.semibold))
                Text("Photo placeholder. The full app keeps pictures on the phone and syncs them later.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct VoiceNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let caption: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(ForgeTheme.ink)
                Text(caption)
                    .font(.headline)
                Text("Playback is a stub. The note is stored with the job on this iPhone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .navigationTitle("Voice note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct QuoteSummaryRow: View {
    let quote: Quote

    private var total: Decimal {
        MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints).total
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.number)
                    .font(ForgeType.rowTitle)
                Text(FieldFormat.money(total))
                    .font(ForgeType.rowMoney)
                    .foregroundStyle(ForgeTheme.money)
            }
            Spacer()
            StatusChip(title: quote.status.label, tint: ForgeTheme.quoteTint(quote.status))
        }
        .padding(.vertical, 6)
    }
}
