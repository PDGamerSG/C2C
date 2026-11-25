import AppKit
import C2CCore
import ImageIO

@MainActor
enum ClipImageRenderer {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 120
        cache.totalCostLimit = 32 * 1_024 * 1_024
        return cache
    }()

    /// Downsample before decoding so large screenshots do not fill memory in the list.
    static func image(for clip: Clip, maximumPixels: Int) -> NSImage? {
        let key = "\(clip.id)-\(maximumPixels)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        for payload in clip.payloads where payload.kind == .image {
            guard let source = CGImageSourceCreateWithData(payload.data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixels
                  ] as CFDictionary) else { continue }
            let image = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
            cache.setObject(image, forKey: key, cost: thumbnail.bytesPerRow * thumbnail.height)
            return image
        }
        return nil
    }
}
