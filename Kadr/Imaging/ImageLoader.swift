import ImageIO
import CoreGraphics
import Foundation

enum ImageLoader {
    /// Decodes a photo upright (EXIF orientation applied) and shrinks it so its
    /// long side is at most `maxSide`. Never enlarges.
    static func load(data: Data, maxSide: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        var limit = maxSide
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? Int,
           let h = props[kCGImagePropertyPixelHeight] as? Int {
            limit = min(maxSide, max(w, h))
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: limit
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
