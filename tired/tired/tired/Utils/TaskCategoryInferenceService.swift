import Foundation

/// 任務分類推斷服務
/// 負責根據組織類型、用戶上下文等智能推斷任務分類
class TaskCategoryInferenceService {

    private let organizationService: OrganizationService

    init(organizationService: OrganizationService = OrganizationService()) {
        self.organizationService = organizationService
    }

    /// 從組織ID推斷任務分類
    func inferCategoryFromOrgId(_ orgId: String?) async -> TaskCategory {
        guard let orgId = orgId else {
            return .personal
        }

        do {
            let org = try await organizationService.fetchOrganization(id: orgId)
            return TaskCategory.inferFromOrgType(org.type)
        } catch {
            print("獲取組織資訊失敗，使用預設分類: \(error)")
            return .personal
        }
    }

    /// 從組織類型推斷任務分類
    func inferCategoryFromOrgType(_ orgType: OrgType, departmentContext: String? = nil) -> TaskCategory {
        switch orgType {
        case .school:
            return .school
        case .course:
            return .school  // 課程屬於學校分類
        case .company, .project:
            return .work
        case .club:
            return .club
        case .department:
            // 檢查部門上下文，如果是學校相關則為學校分類
            if let context = departmentContext?.lowercased(),
               context.contains("學校") || context.contains("学院") || context.contains("大學") {
                return .school
            }
            return .work
        case .other:
            return .personal
        }
    }

    /// 從任務標題和描述分析分類（AI風格）
    func analyzeCategoryFromContent(title: String, description: String?) -> TaskCategory? {
        let content = (title + " " + (description ?? "")).lowercased()

        // 學校關鍵字
        let schoolKeywords = ["作業", "考试", "課程", "老師", "教授", "學校", "大學", "学院", "學期", "成績"]
        if schoolKeywords.contains(where: { content.contains($0) }) {
            return .school
        }

        // 工作關鍵字
        let workKeywords = ["會議", "報告", "專案", "客戶", "老板", "同事", "截止日期", "任務分配", "工作", "業務"]
        if workKeywords.contains(where: { content.contains($0) }) {
            return .work
        }

        // 社團關鍵字
        let clubKeywords = ["社團", "活動", "聚會", "排練", "演出", "比賽", "訓練", "團隊"]
        if clubKeywords.contains(where: { content.contains($0) }) {
            return .club
        }

        return nil // 無法確定分類
    }

    /// 智能建議分類
    func suggestCategory(
        title: String,
        description: String?,
        orgId: String?,
        userContext: UserContext?
    ) async -> TaskCategory {
        // 1. 優先使用組織推斷
        if let orgId = orgId {
            let orgCategory = await inferCategoryFromOrgId(orgId)
            if orgCategory != .personal {
                return orgCategory
            }
        }

        // 2. 使用內容分析
        if let contentCategory = analyzeCategoryFromContent(title: title, description: description) {
            return contentCategory
        }

        // 3. 使用用戶上下文
        if let context = userContext {
            return inferFromUserContext(context)
        }

        // 4. 預設個人
        return .personal
    }

    /// 從用戶上下文推斷分類
    private func inferFromUserContext(_ context: UserContext) -> TaskCategory {
        // 根據用戶當前活躍的身份推斷
        switch context.currentActiveIdentity {
        case .student:
            return .school
        case .employee:
            return .work
        case .clubMember:
            return .club
        case .personal:
            return .personal
        }
    }
}

/// 用戶上下文結構
struct UserContext {
    var currentActiveIdentity: UserIdentity
    var recentTaskCategories: [TaskCategory]
    var timeOfDay: Date

    enum UserIdentity {
        case student
        case employee
        case clubMember
        case personal
    }
}

/// 任務分類擴展
extension TaskCategory {
    /// 從組織類型推斷任務分類
    static func inferFromOrgType(_ orgType: OrgType) -> TaskCategory {
        switch orgType {
        case .school:
            return .school
        case .course:
            return .school  // 課程屬於學校分類
        case .department:
            // 部門預設為工作，可以根據具體情況調整
            return .work
        case .club:
            return .club
        case .company, .project:
            return .work
        case .other:
            return .personal
        }
    }
}