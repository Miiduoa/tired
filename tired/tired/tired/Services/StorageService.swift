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

    // MARK: - Delete Images

    /// 刪除圖片
    func deleteImage(url: String) async throws {
        let storageRef = storage.reference(forURL: url)
        try await storageRef.delete()
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
