import ImageIO
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

    @discardableResult
    static func install(_ data: Data, fileName: String) -> Bool {
        guard fileName.isEmpty == false else { return false }
        do {
            try data.write(to: url(for: fileName), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func duplicateFolder() -> URL? {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("fieldforge-rescue-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.copyItem(at: directory(), to: destination)
            return destination
        } catch {
            return nil
        }
    }

    @discardableResult
    static func replaceFolder(with source: URL) -> Bool {
        let destination = directory()
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return true
        } catch {
            return false
        }
    }

    static func remove(_ fileName: String) {
        guard fileName.isEmpty == false else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    static func image(fileName: String, maxPixel: Int) async -> UIImage? {
        guard fileName.isEmpty == false else { return nil }
        let key = "\(maxPixel)-\(fileName)" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        let url = url(for: fileName)
        let rendered = await Task.detached(priority: .utility) {
            downsampledImage(at: url, maxPixel: maxPixel)
        }.value
        if let rendered {
            thumbnailCache.setObject(rendered, forKey: key)
        }
        return rendered
    }

    nonisolated static func downsampledImage(at url: URL, maxPixel: Int) -> UIImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image)
    }

    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 96
        return cache
    }()

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
