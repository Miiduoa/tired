import Foundation
import UIKit

enum FileUploadError: Error {
    case invalidFile
    case uploadFailed(String)
    case fileTooLarge
    case unsupportedFormat
}

/// 文件上傳服務
class FileUploadService {
    
    static let shared = FileUploadService()
    
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let supportedImageFormats: Set<String> = ["jpg", "jpeg", "png", "heic"]
    private let supportedDocumentFormats: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx"]
    
    private init() {}
    
    // MARK: - 圖片上傳
    
    /// 上傳圖片
    /// - Parameters:
    ///   - image: UIImage 對象
    ///   - compress: 是否壓縮（默認 true）
    ///   - quality: 壓縮質量（0.0-1.0，默認 0.8）
    /// - Returns: 上傳後的 URL
    func uploadImage(
        _ image: UIImage,
        compress: Bool = true,
        quality: CGFloat = 0.8
    ) async throws -> String {
        var imageData: Data?
        
        if compress {
            imageData = image.jpegData(compressionQuality: quality)
        } else {
            imageData = image.pngData()
        }
        
        guard let data = imageData else {
            throw FileUploadError.invalidFile
        }
        
        guard data.count <= maxFileSize else {
            throw FileUploadError.fileTooLarge
        }
        
        return try await uploadFile(data: data, mimeType: "image/jpeg", filename: "image_\(UUID().uuidString).jpg")
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
        let filename = "\(category.rawValue)_\(UUID().uuidString).\(fileExtension)"
        
        return try await uploadFile(data: data, mimeType: mimeType, filename: filename)
    }
    
    // MARK: - 底層上傳實現
    
    private func uploadFile(
        data: Data,
        mimeType: String,
        filename: String
    ) async throws -> String {
        guard let endpoint = ProcessInfo.processInfo.environment["TIRED_API_URL"],
              let url = URL(string: "\(endpoint)/v1/files/upload")
        else {
            // 離線模式：返回本地 URL
            return "local://\(filename)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // 添加文件數據
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FileUploadError.uploadFailed("Upload failed with status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let fileUrl = obj["url"] as? String {
            return fileUrl
        }
        
        throw FileUploadError.uploadFailed("Invalid response format")
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

