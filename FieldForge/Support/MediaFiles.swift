import UIKit

enum MediaFiles {
    static func url(for fileName: String) -> URL {
        directory().appendingPathComponent(fileName)
    }

    static func saveJPEG(_ image: UIImage) -> String? {
        guard let data = jpegData(from: image) else { return nil }
        let fileName = "photo-\(UUID().uuidString).jpg"
        do {
            try data.write(to: url(for: fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func saveAudio(from source: URL) -> String? {
        let fileName = "voice-\(UUID().uuidString).m4a"
        let destination = url(for: fileName)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return fileName
        } catch {
            return nil
        }
    }

    static func remove(_ fileName: String) {
        guard fileName.isEmpty == false else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    static func image(for photo: JobPhoto) -> UIImage? {
        guard photo.fileName.isEmpty == false else { return nil }
        return UIImage(contentsOfFile: url(for: photo.fileName).path)
    }

    private static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FieldForgeMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func jpegData(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 1600
        let longest = max(image.size.width, image.size.height)
        let scale = longest > 0 ? min(1, maxSide / longest) : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}
