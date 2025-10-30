
import Foundation
import SwiftUI
import Combine

/// 通用 ViewModel 基類，提供統一的狀態管理和錯誤處理
@MainActor
class BaseViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var errorMessage: String?
    
    // MARK: - 狀態管理
    
    func setLoading(_ loading: Bool) {
        withAnimation(TTokens.animationQuick) {
            isLoading = loading
        }
    }
    
    func setError(_ error: Error) {
        self.error = error
        self.errorMessage = error.localizedDescription
        setLoading(false)
    }
    
    func clearError() {
        error = nil
        errorMessage = nil
    }
    
    // MARK: - 執行任務（帶錯誤處理）
    
    func executeTask<T>(
        loading: Bool = true,
        errorHandler: ((Error) -> Void)? = nil,
        task: @escaping () async throws -> T
    ) async -> T? {
        if loading {
            setLoading(true)
        }
        clearError()
        
        defer {
            if loading {
                setLoading(false)
            }
        }
        
        do {
            return try await task()
        } catch {
            setError(error)
            errorHandler?(error)
            return nil
        }
    }
    
    // MARK: - 執行任務（返回結果）
    
    func executeTask<T>(
        loading: Bool = true,
        errorHandler: ((Error) -> Void)? = nil,
        task: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        if loading {
            setLoading(true)
        }
        clearError()
        
        defer {
            if loading {
                setLoading(false)
            }
        }
        
        do {
            let result = try await task()
            return .success(result)
        } catch {
            setError(error)
            errorHandler?(error)
            return .failure(error)
        }
    }
}

// MARK: - 數據載入協議

protocol DataLoadable {
    associatedtype DataType
    func load() async
    var items: [DataType] { get }
    var isEmpty: Bool { get }
}

extension DataLoadable where Self: BaseViewModel {
    var isEmpty: Bool {
        items.isEmpty
    }
}


