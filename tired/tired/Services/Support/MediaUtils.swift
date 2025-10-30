import UIKit

enum MediaUtils {
    static func resizedImageData(_ image: UIImage, maxDimension: Int, maxBytes: Int, initialQuality: CGFloat = 0.9) -> Data? {
        let targetSize = targetSizeFor(image.size, maxDimension: CGFloat(maxDimension))
        let scaled = imageByScaling(image, to: targetSize)
        // Try progressive compression
        var quality = initialQuality
        var data = scaled.jpegData(compressionQuality: quality)
        while let d = data, d.count > maxBytes, quality > 0.4 {
            quality -= 0.1
            data = scaled.jpegData(compressionQuality: quality)
        }
        return data
    }

    private static func targetSizeFor(_ size: CGSize, maxDimension: CGFloat) -> CGSize {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return size }
        let scale = maxDimension / maxSide
        return CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
    }

    private static func imageByScaling(_ image: UIImage, to size: CGSize) -> UIImage {
        if image.size == size { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

