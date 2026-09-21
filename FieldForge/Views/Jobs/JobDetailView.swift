import AVFoundation
import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct JobDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var job: Job

    @State private var showEdit = false
    @State private var selectedPhoto: JobPhoto?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraMessage: String?
    @State private var cameraDenied = false
    @State private var libraryDenied = false
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
                                if status == .done {
                                    if job.completedAt == nil { job.completedAt = .now }
                                } else {
                                    job.completedAt = nil
                                }
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
                    Text("Take a picture or choose one from your library. Photos stay on this iPhone with the job.")
                        .font(ForgeType.secondary)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(photos) { photo in
                            Button {
                                selectedPhoto = photo
                            } label: {
                                JobPhotoThumbnail(photo: photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button {
                    openCamera()
                } label: {
                    Label("Take photo", systemImage: "camera")
                        .font(ForgeType.rowTitle)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.borderless)
                if libraryDenied {
                    Text("Photo library access is off. Turn it on in Settings to attach pictures.")
                        .font(ForgeType.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        ForgeSystem.openSettings()
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44, alignment: .leading)
                } else {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose photo", systemImage: "photo")
                            .font(ForgeType.rowTitle)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                }
                if cameraDenied {
                    Text("Camera access is off. Turn it on in Settings to photograph the job.")
                        .font(ForgeType.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        ForgeSystem.openSettings()
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44, alignment: .leading)
                }
            }

            VoiceNotesSection(job: job)

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
            PhotoViewer(photo: photo) {
                deletePhoto(photo)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                storePhoto(image)
            }
        }
        .alert("Camera", isPresented: Binding(
            get: { cameraMessage != nil },
            set: { if $0 == false { cameraMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
            if cameraDenied {
                Button("Open Settings") {
                    ForgeSystem.openSettings()
                }
            }
        } message: {
            Text(cameraMessage ?? "")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importLibraryPhoto(item) }
        }
        .onAppear(perform: refreshCaptureAccess)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshCaptureAccess() }
        }
        .navigationDestination(isPresented: $showNewQuote) {
            if let quoteToOpen {
                QuoteBuilderView(quote: quoteToOpen)
            }
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraMessage = "This device has no camera. Choose a photo from the library instead."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraDenied = false
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { allowed in
                Task { @MainActor in
                    cameraDenied = allowed == false
                    if allowed {
                        showCamera = true
                    } else {
                        cameraMessage = "Camera access is off. Turn it on in Settings to photograph the job."
                    }
                }
            }
        default:
            cameraDenied = true
            cameraMessage = "Camera access is off. Turn it on in Settings to photograph the job."
        }
    }

    private func refreshCaptureAccess() {
        let camera = AVCaptureDevice.authorizationStatus(for: .video)
        cameraDenied = camera == .denied || camera == .restricted
        let library = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        libraryDenied = library == .denied || library == .restricted
    }

    private func importLibraryPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        do {
            if let picked = try await item.loadTransferable(type: PickedPhoto.self) {
                storePhoto(picked.image)
                return
            }
            cameraMessage = "That photo couldn't be added. Try another one."
        } catch {
            cameraMessage = "That photo couldn't be added. Try another one."
        }
    }

    private func storePhoto(_ image: UIImage) {
        guard let fileName = MediaFiles.saveJPEG(image) else {
            cameraMessage = "The photo couldn't be saved on this iPhone."
            return
        }
        let photo = JobPhoto(
            caption: "Site photo \(photos.count + 1)",
            symbolName: "photo",
            fileName: fileName
        )
        context.insert(photo)
        photo.job = job
        job.needsSync = true
        try? context.save()
    }

    private func deletePhoto(_ photo: JobPhoto) {
        MediaFiles.remove(photo.fileName)
        context.delete(photo)
        job.needsSync = true
        try? context.save()
        ForgeHaptic.delete()
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
