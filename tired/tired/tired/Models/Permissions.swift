import Foundation

/// 定義所有可能存在的權限字串，用於角色權限管理
struct AppPermissions {
    // 貼文相關權限
    static let createPostInOrg = "create_post_in_org"
    static let createAnnouncementInOrg = "create_announcement_in_org"
    static let deleteAnyPostInOrg = "delete_any_post_in_org" // 允許刪除組織內任何貼文
    static let deleteOwnPost = "delete_own_post" // 允許刪除自己的貼文 (通常預設允許)
    
    // 成員管理相關權限
    static let manageOrgMembers = "manage_org_members" // 允許邀請、移除成員，修改成員角色
    
    // 角色管理相關權限
    static let manageOrgRoles = "manage_org_roles" // 允許創建、編輯、刪除組織角色
    
    // 活動管理相關權限
    static let createEventInOrg = "create_event_in_org"
    static let editAnyEventInOrg = "edit_any_event_in_org"
    static let deleteAnyEventInOrg = "delete_any_event_in_org"
    
    // 任務管理相關權限
    static let createTaskInOrg = "create_task_in_org"
    static let editAnyTaskInOrg = "edit_any_task_in_org"
    static let deleteAnyTaskInOrg = "delete_any_task_in_org"
    static let assignTaskInOrg = "assign_task_in_org" // 允許分配任務給組織成員
    static let manageAllOrgTasks = "manage_all_org_tasks" // 允許管理所有組織任務 (編輯、刪除、完成)
    
    // 任務評論相關權限
    static let createTaskCommentInOrg = "create_task_comment_in_org"
    static let deleteAnyTaskCommentInOrg = "delete_any_task_comment_in_org"
    static let deleteOwnTaskComment = "delete_own_task_comment"
    
    // 貼文評論相關權限
    static let createPostCommentInOrg = "create_post_comment_in_org" // 在組織貼文下發表評論
    static let deleteAnyPostCommentInOrg = "delete_any_post_comment_in_org" // 刪除組織貼文下的任何評論
    static let deleteOwnPostComment = "delete_own_post_comment" // 刪除自己的貼文評論
    
    // 組織設定相關權限
    static let editOrgSettings = "edit_org_settings" // 允許編輯組織基本資訊、頭像等
    static let deleteOrganization = "delete_organization" // 允許刪除整個組織
    
    // 應用實例管理權限 (OrgApp)
    static let manageOrgApps = "manage_org_apps" // 允許新增/移除組織應用實例
}