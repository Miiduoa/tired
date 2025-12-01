import Foundation
import FirebaseStorage
import UIKit

/// Firebase Storage 服務
class StorageService {
    private let storage = Storage.storage()

    enum StorageError: LocalizedError {
        case invalidImageData
        case uploadFailed(Error)
        case downloadUrlFailed

        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "無效的圖片資料"
            case .uploadFailed(let error):
                return "上傳失敗：\(error.localizedDescription)"
            case .downloadUrlFailed:
                return "無法獲取下載連結"
            }
        }
    }

    // MARK: - Upload Images

    /// 上傳用戶頭像
    func uploadAvatar(userId: String, imageData: Data) async throws -> String {
        let path = "avatars/\(userId)/\(UUID().uuidString).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    /// 上傳組織頭像
    func uploadOrganizationAvatar(organizationId: String, imageData: Data) async throws -> String {
        let path = "organizations/\(organizationId)/avatar/\(UUID().uuidString).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    /// 上傳組織封面
    func uploadOrganizationCover(organizationId: String, imageData: Data) async throws -> String {
        let path = "organizations/\(organizationId)/cover/\(UUID().uuidString).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    /// 上傳貼文圖片
    func uploadPostImage(userId: String, imageData: Data) async throws -> String {
        let path = "posts/\(userId)/\(UUID().uuidString).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    /// 上傳活動圖片
    func uploadEventImage(organizationId: String, imageData: Data) async throws -> String {
        let path = "events/\(organizationId)/\(UUID().uuidString).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    // MARK: - Upload Files (Moodle-like Resource Management)

    /// 上傳組織資源文件
    func uploadResourceFile(organizationId: String, fileData: Data, fileName: String, mimeType: String) async throws -> String {
        let fileExtension = (fileName as NSString).pathExtension
        let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
        let path = "resources/\(organizationId)/\(uniqueFileName)"
        return try await uploadFile(data: fileData, path: path, mimeType: mimeType)
    }

    /// 上傳作業附件
    func uploadAssignmentFile(userId: String, taskId: String, fileData: Data, fileName: String, mimeType: String) async throws -> String {
        let fileExtension = (fileName as NSString).pathExtension
        let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
        let path = "assignments/\(userId)/\(taskId)/\(uniqueFileName)"
        return try await uploadFile(data: fileData, path: path, mimeType: mimeType)
    }

    // MARK: - Core Upload Function

    /// 核心圖片上傳功能
    private func uploadImage(data: Data, path: String) async throws -> String {
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            // 上傳圖片
            _ = try await storageRef.putDataAsync(data, metadata: metadata)

            // 獲取下載 URL
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw StorageError.uploadFailed(error)
        }
    }

    /// 核心文件上傳功能（支援所有類型文件）
    private func uploadFile(data: Data, path: String, mimeType: String) async throws -> String {
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = mimeType

        do {
            // 上傳文件
            _ = try await storageRef.putDataAsync(data, metadata: metadata)

            // 獲取下載 URL
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw StorageError.uploadFailed(error)
        }
    }

    // MARK: - Delete Images

    /// 刪除圖片或文件
    func deleteImage(url: String) async throws {
        let storageRef = storage.reference(forURL: url)
        try await storageRef.delete()
    }

    /// 刪除文件（別名，語意更清晰）
    func deleteFile(url: String) async throws {
        try await deleteImage(url: url)
    }

    // MARK: - Download Files

    /// 下載文件資料
    func downloadFile(url: String) async throws -> Data {
        let storageRef = storage.reference(forURL: url)
        let data = try await storageRef.data(maxSize: 50 * 1024 * 1024) // 最大 50MB
        return data
    }

    // MARK: - Helper Methods

    /// 根據檔案副檔名獲取 MIME 類型
    func getMimeType(for fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()

        switch fileExtension {
        // 文件
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "csv": return "text/csv"

        // 圖片
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"

        // 影片
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"

        // 音訊
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"

        // 壓縮檔
        case "zip": return "application/zip"
        case "rar": return "application/x-rar-compressed"
        case "7z": return "application/x-7z-compressed"

        default: return "application/octet-stream"
        }
    }

    // MARK: - Helper Methods

    /// 壓縮圖片資料
    func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)

        // 逐步降低壓縮質量直到符合大小限制
        while let data = imageData, data.count > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }

        return imageData
    }

    /// 調整圖片大小
    func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height

        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // 如果圖片已經比目標小，直接返回
        if size.width <= newSize.width && size.height <= newSize.height {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }
}
