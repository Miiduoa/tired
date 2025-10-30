import UIKit
import AVFoundation

@MainActor
final class VideoThumbnailCache {
    static let shared = VideoThumbnailCache()
    private let mem = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "VideoThumb.disk.cache")
    private var maxDiskItems: Int { AppConfig.videoThumbMaxItems }
    private var ttlDays: Int { AppConfig.videoThumbTtlDays }

    private init() { mem.countLimit = 200 }

    func thumbnail(for url: URL, at seconds: Double = 0.2) async -> UIImage? {
        let key = cacheKey(for: url)
        if let cached = mem.object(forKey: key as NSString) { return cached }
        if let disk = loadFromDisk(key: key) {
            mem.setObject(disk, forKey: key as NSString)
            return disk
        }
        // Generate
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        do {
            let cg = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CGImage, Error>) in
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImg, _, result, err in
                    if let cgImg { cont.resume(returning: cgImg) }
                    else { cont.resume(throwing: err ?? NSError(domain: "thumb", code: -1)) }
                }
            }
            let img = UIImage(cgImage: cg)
            mem.setObject(img, forKey: key as NSString)
            saveToDisk(image: img, key: key)
            return img
        } catch {
            return nil
        }
    }

    private func cacheKey(for url: URL) -> String { "vthumb_" + (url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? url.absoluteString) }

    private func cacheDir() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("VideoThumbnails", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let url = cacheDir().appendingPathComponent(key + ".jpg")
        guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
        return img
    }

    private func saveToDisk(image: UIImage, key: String) {
        ioQueue.async {
            let url = self.cacheDir().appendingPathComponent(key + ".jpg")
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            try? data.write(to: url, options: .atomic)
            self.enforceDiskLimit()
        }
    }

    private func enforceDiskLimit() {
        let dir = cacheDir()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }
        // Remove expired files first
        let now = Date()
        let ttl: TimeInterval = Double(ttlDays) * 24 * 3600
        let expired = files.filter { url in
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return now.timeIntervalSince(mod) > ttl
        }
        expired.forEach { try? FileManager.default.removeItem(at: $0) }

        let remaining = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        if remaining.count <= maxDiskItems { return }
        let sorted = remaining.sorted { (a, b) -> Bool in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return da < db
        }
        let toRemove = sorted.prefix(remaining.count - maxDiskItems)
        toRemove.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    func cleanup() {
        ioQueue.async { self.enforceDiskLimit() }
    }
}
