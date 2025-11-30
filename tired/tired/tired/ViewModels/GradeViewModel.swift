import Foundation
import Combine
import FirebaseAuth
import SwiftUI

/// 成績視圖的 ViewModel
@MainActor
class GradeViewModel: ObservableObject {
    @Published var grades: [Grade] = []
    @Published var gradeItems: [GradeItem] = []
    @Published var gradeCategories: [GradeCategory] = []
    @Published var gradeSummary: GradeSummary?
    @Published var gradeStatistics: GradeStatistics?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 篩選和排序
    @Published var selectedOrganizationId: String?
    @Published var selectedGradeItemId: String?
    @Published var showOnlyGraded = false
    @Published var isStudentView = true  // 新增：true = 學員視角, false = 教師視角

    private let gradeService = GradeService()
    private let userService = UserService()
    private var cancellables = Set<AnyCancellable>()
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    init() {
        // 初始化時不自動載入，由 View 調用 loadGrades
    }
    
    // MARK: - Grade Loading
    
    /// 載入學員的成績（實時監聽）
    func loadStudentGrades(organizationId: String) {
        guard let userId = userId else {
            errorMessage = "用戶未登入"
            return
        }
        
        isLoading = true
        cancellables.removeAll()
        
        gradeService.getStudentGrades(userId: userId, organizationId: organizationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "載入成績失敗：\(error.localizedDescription)"
                        self?.isLoading = false
                    }
                },
                receiveValue: { [weak self] grades in
                    self?.grades = grades
                    self?.errorMessage = nil
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    /// 載入課程的所有成績（教師視角）
    func loadCourseGrades(organizationId: String, gradeItemId: String? = nil) {
        isLoading = true
        cancellables.removeAll()
        
        gradeService.getCourseGrades(organizationId: organizationId, gradeItemId: gradeItemId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "載入成績失敗：\(error.localizedDescription)"
                        self?.isLoading = false
                    }
                },
                receiveValue: { [weak self] grades in
                    self?.grades = grades
                    self?.errorMessage = nil
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    /// 載入成績項目
    func loadGradeItems(organizationId: String) {
        cancellables.removeAll()
        
        gradeService.getGradeItems(organizationId: organizationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "載入成績項目失敗：\(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] items in
                    self?.gradeItems = items
                }
            )
            .store(in: &cancellables)
    }
    
    /// 載入成績分類
    func loadGradeCategories(organizationId: String) async {
        do {
            let categories = try await gradeService.getGradeCategories(organizationId: organizationId)
            gradeCategories = categories
        } catch {
            errorMessage = "載入成績分類失敗：\(error.localizedDescription)"
        }
    }
    
    /// 計算總成績
    func calculateFinalGrade(organizationId: String) async {
        guard let userId = userId else {
            errorMessage = "用戶未登入"
            return
        }
        
        do {
            let summary = try await gradeService.calculateFinalGrade(userId: userId, organizationId: organizationId)
            gradeSummary = summary
        } catch {
            errorMessage = "計算總成績失敗：\(error.localizedDescription)"
        }
    }
    
    /// 載入成績統計
    func loadGradeStatistics(organizationId: String, gradeItemId: String? = nil) async {
        do {
            let statistics = try await gradeService.getGradeStatistics(organizationId: organizationId, gradeItemId: gradeItemId)
            gradeStatistics = statistics
        } catch {
            errorMessage = "載入成績統計失敗：\(error.localizedDescription)"
        }
    }
    
    // MARK: - Grade Actions
    
    /// 創建成績
    func createGrade(_ grade: Grade) async -> Bool {
        do {
            _ = try await gradeService.createGrade(grade)
            ToastManager.shared.showToast(message: "成績創建成功", type: .success)
            return true
        } catch {
            errorMessage = "創建成績失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: errorMessage ?? "創建成績失敗", type: .error)
            return false
        }
    }
    
    /// 更新成績
    func updateGrade(gradeId: String, score: Double? = nil, grade: LetterGrade? = nil, isPass: Bool? = nil, feedback: String? = nil, rubricScores: [RubricScore]? = nil, isReleased: Bool? = nil) async -> Bool {
        do {
            try await gradeService.updateGrade(
                gradeId: gradeId,
                score: score,
                grade: grade,
                isPass: isPass,
                feedback: feedback,
                rubricScores: rubricScores,
                isReleased: isReleased
            )
            ToastManager.shared.showToast(message: "成績更新成功", type: .success)
            return true
        } catch {
            errorMessage = "更新成績失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: errorMessage ?? "更新成績失敗", type: .error)
            return false
        }
    }
    
    /// 刪除成績
    func deleteGrade(gradeId: String) async -> Bool {
        do {
            try await gradeService.deleteGrade(gradeId: gradeId)
            ToastManager.shared.showToast(message: "成績已刪除", type: .success)
            return true
        } catch {
            errorMessage = "刪除成績失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: errorMessage ?? "刪除成績失敗", type: .error)
            return false
        }
    }
    
    /// 批量創建成績
    func createGrades(_ grades: [Grade]) async -> Bool {
        do {
            _ = try await gradeService.createGrades(grades)
            ToastManager.shared.showToast(message: "批量創建成績成功", type: .success)
            return true
        } catch {
            errorMessage = "批量創建成績失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: errorMessage ?? "批量創建成績失敗", type: .error)
            return false
        }
    }
    
    // MARK: - Grade Item Actions
    
    /// 創建成績項目
    func createGradeItem(_ item: GradeItem) async -> Bool {
        do {
            _ = try await gradeService.createGradeItem(item)
            ToastManager.shared.showToast(message: "成績項目創建成功", type: .success)
            return true
        } catch {
            errorMessage = "創建成績項目失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: errorMessage ?? "創建成績項目失敗", type: .error)
            return false
        }
    }
    
    /// 更新成績項目
    func updateGradeItem(itemId: String, updates: [String: Any]) async -> Bool {
        do {
            try await gradeService.updateGradeItem(itemId: itemId, updates: updates)
            ToastManager.shared.showToast(message: "成績項目更新成功", type: .success)
            return true
        } catch {
            errorMessage = "更新成績項目失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: errorMessage ?? "更新成績項目失敗", type: .error)
            return false
        }
    }
    
    /// 刪除成績項目
    func deleteGradeItem(itemId: String) async -> Bool {
        do {
            try await gradeService.deleteGradeItem(itemId: itemId)
            ToastManager.shared.showToast(message: "成績項目已刪除", type: .success)
            return true
        } catch {
            errorMessage = "刪除成績項目失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: errorMessage ?? "刪除成績項目失敗", type: .error)
            return false
        }
    }
    
    // MARK: - Filtered Grades
    
    /// 篩選後的成績列表
    var filteredGrades: [Grade] {
        var filtered = grades

        // 學生視角：只顯示已發布的成績（Moodle-like 功能）
        if isStudentView {
            filtered = filtered.filter { $0.isReleased }
        }

        if showOnlyGraded {
            filtered = filtered.filter { $0.isGraded }
        }

        if let gradeItemId = selectedGradeItemId {
            filtered = filtered.filter { $0.gradeItemId == gradeItemId }
        }

        return filtered.sorted { grade1, grade2 in
            // 按創建時間降序排列
            grade1.createdAt > grade2.createdAt
        }
    }
    
    /// 獲取任務的成績
    func getGradeForTask(taskId: String) async -> Grade? {
        do {
            return try await gradeService.getTaskGrade(taskId: taskId)
        } catch {
            errorMessage = "獲取任務成績失敗：\(error.localizedDescription)"
            return nil
        }
    }
}

