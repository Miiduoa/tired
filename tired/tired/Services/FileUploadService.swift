import Foundation
import UIKit
import FirebaseStorage
import UniformTypeIdentifiers

enum FileUploadError: Error {
    case invalidFile
    case uploadFailed(String)
    case fileTooLarge
    case unsupportedFormat
    case compressionFailed
    case storageError(Error)
}

/// 文件上傳服務（整合 Firebase Storage）
@MainActor
class FileUploadService {
    
    static let shared = FileUploadService()
    
    private let storage = Storage.storage()
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxImageSize: Int = 5 * 1024 * 1024 // 5MB for images
    private let supportedImageFormats: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]
    private let supportedDocumentFormats: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx", "txt"]
    
    private init() {}
    
    // MARK: - 圖片上傳
    
    /// 上傳圖片到 Firebase Storage
    /// - Parameters:
    ///   - image: UIImage 對象
    ///   - category: 圖片分類
    ///   - compress: 是否壓縮（默認 true）
    ///   - quality: 壓縮質量（0.0-1.0，默認 0.8）
    ///   - maxDimension: 最大尺寸（寬或高，默認 1920）
    /// - Returns: 上傳後的下載 URL
    func uploadImage(
        _ image: UIImage,
        category: FileCategory = .image,
        compress: Bool = true,
        quality: CGFloat = 0.8,
        maxDimension: CGFloat = 1920
    ) async throws -> String {
        // 調整圖片大小
        var processedImage = image
        if compress {
            processedImage = resizeImage(image, maxDimension: maxDimension)
        }
        
        // 壓縮圖片
        guard var imageData = processedImage.jpegData(compressionQuality: quality) else {
            throw FileUploadError.compressionFailed
        }
        
        // 如果壓縮後還是太大，進一步壓縮
        var currentQuality = quality
        while imageData.count > maxImageSize && currentQuality > 0.1 {
            currentQuality -= 0.1
            guard let newData = processedImage.jpegData(compressionQuality: currentQuality) else {
                break
            }
            imageData = newData
        }
        
        // 檢查文件大小
        guard imageData.count <= maxImageSize else {
            throw FileUploadError.fileTooLarge
        }
        
        // 上傳到 Firebase Storage
        let filename = "\(category.rawValue)/\(UUID().uuidString).jpg"
        return try await uploadToFirebaseStorage(data: imageData, path: filename, contentType: "image/jpeg")
    }
    
    /// 調整圖片大小
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            // 橫向圖片
            if size.width > maxDimension {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                return image
            }
        } else {
            // 豎向圖片
            if size.height > maxDimension {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            } else {
                return image
            }
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    // MARK: - 文件上傳
    
    /// 上傳文件
    /// - Parameters:
    ///   - fileURL: 文件 URL
    ///   - category: 文件分類（用於組織存儲路徑）
    /// - Returns: 上傳後的 URL
    func uploadFile(
        from fileURL: URL,
        category: FileCategory = .document
    ) async throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FileUploadError.invalidFile
        }
        
        let data = try Data(contentsOf: fileURL)
        
        guard data.count <= maxFileSize else {
            throw FileUploadError.fileTooLarge
        }
        
        let fileExtension = fileURL.pathExtension.lowercased()
        guard isSupported(extension: fileExtension) else {
            throw FileUploadError.unsupportedFormat
        }
        
        let mimeType = getMimeType(for: fileExtension)
        let path = "\(category.rawValue)/\(UUID().uuidString).\(fileExtension)"
        
        return try await uploadToFirebaseStorage(data: data, path: path, contentType: mimeType)
    }
    
    // MARK: - Firebase Storage 上傳
    
    /// 上傳到 Firebase Storage
    private func uploadToFirebaseStorage(
        data: Data,
        path: String,
        contentType: String
    ) async throws -> String {
        do {
            let storageRef = storage.reference().child(path)
            let metadata = StorageMetadata()
            metadata.contentType = contentType
            
            // 上傳數據
            let _ = try await storageRef.putDataAsync(data, metadata: metadata)
            
            // 獲取下載 URL
            let downloadURL = try await storageRef.downloadURL()
            
            print("✅ 文件上傳成功: \(path)")
            return downloadURL.absoluteString
        } catch {
            print("❌ 文件上傳失敗: \(error.localizedDescription)")
            throw FileUploadError.storageError(error)
        }
    }
    
    /// 刪除 Firebase Storage 中的文件
    func deleteFile(url: String) async throws {
        do {
            // 從 URL 提取路徑
            guard let urlComponents = URLComponents(string: url),
                  let path = urlComponents.path.components(separatedBy: "/o/").last?.removingPercentEncoding else {
                throw FileUploadError.invalidFile
            }
            
            let storageRef = storage.reference().child(path)
            try await storageRef.delete()
            
            print("✅ 文件已刪除: \(path)")
        } catch {
            print("❌ 刪除文件失敗: \(error.localizedDescription)")
            throw FileUploadError.storageError(error)
        }
    }
    
    // MARK: - 批量上傳
    
    /// 批量上傳圖片
    /// - Parameters:
    ///   - images: 圖片數組
    ///   - compress: 是否壓縮
    ///   - quality: 壓縮質量
    ///   - progress: 進度回調
    /// - Returns: 上傳後的 URLs
    func uploadImages(
        _ images: [UIImage],
        compress: Bool = true,
        quality: CGFloat = 0.8,
        progress: ((Int, Int) -> Void)? = nil
    ) async throws -> [String] {
        var urls: [String] = []
        
        for (index, image) in images.enumerated() {
            let url = try await uploadImage(image, compress: compress, quality: quality)
            urls.append(url)
            progress?(index + 1, images.count)
        }
        
        return urls
    }
    
    // MARK: - 輔助方法
    
    private func isSupported(extension ext: String) -> Bool {
        return supportedImageFormats.contains(ext) || supportedDocumentFormats.contains(ext)
    }
    
    private func getMimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - 文件分類

enum FileCategory: String {
    case document = "docs"
    case image = "images"
    case avatar = "avatars"
    case esg = "esg"
    case evidence = "evidence"
}

