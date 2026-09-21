import AVFoundation
import CoreTransferable
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PickedPhoto: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return PickedPhoto(image: image)
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImage: (UIImage) -> Void
        var dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

struct JobPhotoThumbnail: View {
    let photo: JobPhoto
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: photo.symbolName.isEmpty ? "photo" : photo.symbolName)
                    .font(.title2)
                    .foregroundStyle(ForgeTheme.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemFill))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: ForgeTheme.Radius.s, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ForgeTheme.Radius.s, style: .continuous)
                .strokeBorder(ForgeTheme.border, lineWidth: 1)
        }
        .accessibilityLabel(photo.caption.isEmpty ? "Job photo" : photo.caption)
        .task(id: photo.fileName) {
            guard photo.fileName.isEmpty == false else {
                image = nil
                return
            }
            image = await MediaFiles.image(fileName: photo.fileName, maxPixel: 360)
        }
    }
}

struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let photo: JobPhoto
    var onDelete: () -> Void

    @State private var confirmDelete = false
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: ForgeTheme.Space.s) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: photo.symbolName.isEmpty ? "photo" : photo.symbolName)
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(ForgeTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 220)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: ForgeTheme.Radius.l, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity)
                if photo.caption.isEmpty == false {
                    Text(photo.caption)
                        .font(ForgeType.section)
                }
                Text(photo.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(ForgeTheme.Space.l)
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete photo")
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete photo", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The picture is removed from this job on the iPhone.")
            }
            .task(id: photo.fileName) {
                guard photo.fileName.isEmpty == false else { return }
                image = await MediaFiles.image(fileName: photo.fileName, maxPixel: 1400)
            }
        }
    }
}

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var failure: String?

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var timer: Timer?
    private var startedAt = Date.now

    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    func start() {
        failure = nil
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("fieldforge-voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                failure = "This iPhone couldn't start the recording."
                return
            }
            self.recorder = recorder
            fileURL = url
            startedAt = .now
            elapsed = 0
            isRecording = true
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isRecording else { return }
                    self.elapsed = Date.now.timeIntervalSince(self.startedAt)
                }
            }
        } catch {
            failure = "This iPhone couldn't start the recording."
            isRecording = false
        }
    }

    func stop() -> (url: URL, duration: TimeInterval)? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        let duration = Date.now.timeIntervalSince(startedAt)
        let url = fileURL
        recorder = nil
        fileURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        guard let url else { return nil }
        if duration < 0.4 {
            try? FileManager.default.removeItem(at: url)
            failure = "That clip was too short to keep."
            return nil
        }
        return (url, duration)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        fileURL = nil
    }
}

@MainActor
final class VoicePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playingFile: String?

    private var player: AVAudioPlayer?

    func toggle(fileName: String) {
        if playingFile == fileName {
            stop()
            return
        }
        stop()
        let url = MediaFiles.url(for: fileName)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            self.player = player
            playingFile = fileName
        } catch {
            playingFile = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingFile = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playingFile = nil
            self.player = nil
        }
    }
}

struct VoiceNotesSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var job: Job
    @StateObject private var recorder = VoiceRecorder()
    @StateObject private var player = VoicePlayer()
    @State private var micDenied = false
    @State private var noteToDelete: VoiceNote?

    private var notes: [VoiceNote] {
        job.voiceNotes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Section("Voice notes") {
            if job.voiceMemoCaption.isEmpty == false && notes.isEmpty {
                Text(job.voiceMemoCaption)
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
            }
            if notes.isEmpty && job.voiceMemoCaption.isEmpty {
                Text("Record a note on site. Clips stay on this iPhone with the job.")
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
            }
            ForEach(notes) { note in
                HStack(spacing: 12) {
                    Button {
                        player.toggle(fileName: note.fileName)
                    } label: {
                        Image(systemName: player.playingFile == note.fileName ? "stop.fill" : "play.fill")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(player.playingFile == note.fileName ? "Stop" : "Play voice note")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(durationLabel(note.duration))
                            .font(ForgeType.rowTitle)
                            .monospacedDigit()
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(ForgeType.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        noteToDelete = note
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete voice note")
                }
            }
            Button {
                Task { await toggleRecording() }
            } label: {
                Label(
                    recorder.isRecording ? "Stop \(durationLabel(recorder.elapsed))" : "Record voice note",
                    systemImage: recorder.isRecording ? "stop.circle" : "mic"
                )
                .font(ForgeType.rowTitle)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.borderless)
            if let failure = recorder.failure {
                Text(failure)
                    .font(ForgeType.caption)
                    .foregroundStyle(.secondary)
            }
            if micDenied {
                Text("Microphone access is off. Turn it on in Settings to record notes.")
                    .font(ForgeType.caption)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    ForgeSystem.openSettings()
                }
                .buttonStyle(.borderless)
                .frame(minHeight: 44, alignment: .leading)
            }
        }
        .onDisappear {
            if recorder.isRecording {
                keepRecording()
            }
            player.stop()
        }
        .confirmationDialog("Delete this voice note?", isPresented: Binding(
            get: { noteToDelete != nil },
            set: { if $0 == false { noteToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete note", role: .destructive) {
                if let noteToDelete {
                    if player.playingFile == noteToDelete.fileName {
                        player.stop()
                    }
                    MediaFiles.remove(noteToDelete.fileName)
                    context.delete(noteToDelete)
                    job.needsSync = true
                    try? context.save()
                    ForgeHaptic.delete()
                }
                noteToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func keepRecording() {
        guard let clip = recorder.stop() else { return }
        guard let fileName = MediaFiles.saveAudio(from: clip.url) else {
            recorder.failure = "The recording couldn't be saved."
            return
        }
        try? FileManager.default.removeItem(at: clip.url)
        let note = VoiceNote(fileName: fileName, duration: clip.duration)
        context.insert(note)
        note.job = job
        job.needsSync = true
        try? context.save()
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            keepRecording()
            return
        }
        let allowed = await recorder.requestAccess()
        if allowed {
            micDenied = false
            recorder.start()
        } else {
            micDenied = true
        }
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
