# 數據遷移指南

## 從舊架構（Organization-based）遷移到新架構（Course-based）

本指南說明如何將現有的基於 Organization 的課程數據遷移到新的 Course 模型。

---

## ⚠️ 重要提醒

1. **備份數據**：在執行遷移前，請務必備份 Firestore 數據庫
2. **測試環境**：建議先在測試環境執行遷移
3. **停機時間**：遷移期間可能需要短暫停機
4. **並行運行**：新舊架構可以並存，無需立即遷移

---

## 📋 遷移檢查清單

- [ ] 備份 Firestore 數據庫
- [ ] 在測試環境測試遷移腳本
- [ ] 通知用戶遷移時間
- [ ] 執行遷移
- [ ] 驗證數據完整性
- [ ] 更新客戶端應用
- [ ] 清理舊數據（可選）

---

## 🔄 遷移步驟

### 第一階段：數據映射

#### 1. Organization → Course

```swift
// 舊數據結構
Organization {
    id: "org123"
    type: .course
    name: "資料結構與演算法"
    courseInfo: CourseInfo {
        courseCode: "CS101"
        semester: "2024-1"
        credits: 3
        ...
    }
    parentOrganizationId: "dept456"
    rootOrganizationId: "school789"
}

// 轉換為新數據結構
Course {
    id: "course123"  // 可保持相同 ID
    name: "資料結構與演算法"
    code: "CS101"
    semester: "2024-1"
    credits: 3
    institutionId: "school789"  // 使用 rootOrganizationId
    department: "資訊工程系"     // 從 parent 取得
    createdByUserId: "user123"
    ...
}
```

#### 2. Membership → Enrollment

```swift
// 舊數據結構
Membership {
    id: "mem456"
    userId: "user123"
    organizationId: "org123"
    roleIds: ["role-student"]
}

// 轉換為新數據結構
Enrollment {
    id: "enroll456"  // 可保持相同 ID
    userId: "user123"
    courseId: "course123"
    role: .student  // 固定枚舉，不再是資料庫角色
    status: .active
    enrollmentMethod: .imported
}
```

### 第二階段：遷移腳本

創建遷移服務：

```swift
// Services/MigrationService.swift

class MigrationService {
    private let db = Firestore.firestore()
    private let courseService = CourseService.shared
    private let enrollmentService = EnrollmentService.shared
    
    /// 遷移所有課程類型的組織
    func migrateAllCourses() async throws {
        // 1. 查詢所有 type = course 的組織
        let snapshot = try await db.collection("organizations")
            .whereField("type", isEqualTo: "course")
            .getDocuments()
        
        var successCount = 0
        var failCount = 0
        
        for document in snapshot.documents {
            do {
                guard let org = try? document.data(as: Organization.self) else {
                    failCount += 1
                    continue
                }
                
                // 2. 轉換為 Course
                let course = try await convertOrganizationToCourse(org)
                
                // 3. 保存新課程
                let courseId = try await courseService.createCourse(course)
                
                // 4. 遷移成員
                try await migrateMemberships(
                    fromOrgId: org.id ?? "",
                    toCourseId: courseId
                )
                
                successCount += 1
                print("✅ 成功遷移課程: \(org.name)")
                
            } catch {
                failCount += 1
                print("❌ 遷移失敗: \(document.documentID) - \(error)")
            }
        }
        
        print("\n遷移完成：")
        print("成功: \(successCount)")
        print("失敗: \(failCount)")
    }
    
    /// 將 Organization 轉換為 Course
    private func convertOrganizationToCourse(_ org: Organization) async throws -> Course {
        // 獲取父組織資訊（系所）
        var departmentName: String?
        if let parentId = org.parentOrganizationId {
            let parentOrg = try? await db.collection("organizations")
                .document(parentId)
                .getDocument()
                .data(as: Organization.self)
            departmentName = parentOrg?.name
        }
        
        return Course(
            id: org.id,  // 保持相同 ID
            name: org.name,
            code: org.courseInfo?.courseCode ?? "UNKNOWN",
            description: org.description,
            institutionId: org.rootOrganizationId,
            institutionName: nil,  // 可以補充
            department: departmentName,
            semester: org.courseInfo?.semester ?? "2024-1",
            academicYear: org.courseInfo?.academicYear ?? "2024",
            startDate: nil,  // 可以補充
            endDate: nil,    // 可以補充
            credits: org.courseInfo?.credits,
            courseLevel: .undergraduate,  // 默認值，需手動調整
            maxEnrollment: org.courseInfo?.maxEnrollment,
            isPublic: false,
            isArchived: false,
            syllabus: org.courseInfo?.syllabus,
            schedule: org.schedule ?? [],
            createdAt: org.createdAt,
            updatedAt: org.updatedAt,
            createdByUserId: org.createdByUserId
        )
    }
    
    /// 遷移成員資格
    private func migrateMemberships(fromOrgId: String, toCourseId: String) async throws {
        // 1. 獲取所有成員
        let snapshot = try await db.collection("memberships")
            .whereField("organizationId", isEqualTo: fromOrgId)
            .getDocuments()
        
        // 2. 獲取組織角色映射
        let roleMapping = try await buildRoleMapping(orgId: fromOrgId)
        
        for document in snapshot.documents {
            guard let membership = try? document.data(as: Membership.self) else {
                continue
            }
            
            // 3. 確定新角色
            let newRole = determineNewRole(
                membership: membership,
                roleMapping: roleMapping
            )
            
            // 4. 創建 Enrollment
            let enrollment = Enrollment(
                id: membership.id,  // 保持相同 ID
                userId: membership.userId,
                courseId: toCourseId,
                role: newRole,
                status: .active,
                enrollmentMethod: .imported,
                enrolledAt: membership.createdAt,
                updatedAt: membership.updatedAt
            )
            
            try await enrollmentService.createEnrollment(enrollment)
        }
    }
    
    /// 建立舊角色到新角色的映射
    private func buildRoleMapping(orgId: String) async throws -> [String: CourseRole] {
        let snapshot = try await db.collection("organizations")
            .document(orgId)
            .collection("roles")
            .getDocuments()
        
        var mapping: [String: CourseRole] = [:]
        
        for document in snapshot.documents {
            guard let role = try? document.data(as: Role.self),
                  let roleId = role.id else {
                continue
            }
            
            // 根據角色名稱或權限判斷新角色
            if role.name.contains("擁有者") || role.name.contains("教授") {
                mapping[roleId] = .teacher
            } else if role.name.contains("助教") {
                mapping[roleId] = .ta
            } else if role.name.contains("學生") {
                mapping[roleId] = .student
            } else {
                mapping[roleId] = .observer
            }
        }
        
        return mapping
    }
    
    /// 確定新角色
    private func determineNewRole(
        membership: Membership,
        roleMapping: [String: CourseRole]
    ) -> CourseRole {
        // 取第一個角色作為主要角色
        guard let firstRoleId = membership.roleIds.first,
              let newRole = roleMapping[firstRoleId] else {
            return .student  // 默認為學生
        }
        
        return newRole
    }
    
    /// 驗證遷移結果
    func verifyMigration() async throws -> MigrationReport {
        var report = MigrationReport()
        
        // 統計舊數據
        let orgSnapshot = try await db.collection("organizations")
            .whereField("type", isEqualTo: "course")
            .getDocuments()
        report.oldCoursesCount = orgSnapshot.documents.count
        
        // 統計新數據
        let courseSnapshot = try await db.collection("courses")
            .getDocuments()
        report.newCoursesCount = courseSnapshot.documents.count
        
        // 統計 Enrollment
        let enrollmentSnapshot = try await db.collection("enrollments")
            .getDocuments()
        report.enrollmentsCount = enrollmentSnapshot.documents.count
        
        return report
    }
}

struct MigrationReport {
    var oldCoursesCount: Int = 0
    var newCoursesCount: Int = 0
    var enrollmentsCount: Int = 0
    
    func printReport() {
        print("\n📊 遷移報告")
        print("─────────────────────")
        print("舊課程數量: \(oldCoursesCount)")
        print("新課程數量: \(newCoursesCount)")
        print("選課記錄數: \(enrollmentsCount)")
        print("─────────────────────")
        
        if newCoursesCount >= oldCoursesCount {
            print("✅ 遷移成功")
        } else {
            print("⚠️ 部分課程未遷移")
        }
    }
}
```

### 第三階段：執行遷移

在適當的位置調用遷移：

```swift
// 在管理員工具或測試環境中執行
Task {
    let migration = MigrationService()
    
    do {
        print("開始遷移...")
        try await migration.migrateAllCourses()
        
        print("\n驗證遷移結果...")
        let report = try await migration.verifyMigration()
        report.printReport()
        
    } catch {
        print("❌ 遷移失敗: \(error)")
    }
}
```

---

## 🔍 驗證步驟

### 1. 數據完整性檢查

```swift
// 檢查所有課程都已遷移
let orgCount = // 舊課程數量
let courseCount = // 新課程數量
assert(courseCount >= orgCount, "部分課程未遷移")

// 檢查選課記錄
let membershipCount = // 舊成員數量
let enrollmentCount = // 新選課數量
assert(enrollmentCount >= membershipCount, "部分選課記錄未遷移")
```

### 2. 功能測試

- [ ] 教師可以看到課程列表
- [ ] 學生可以使用選課代碼加入
- [ ] 權限系統正常運作
- [ ] 課表顯示正確
- [ ] 統計資料準確

---

## 🧹 清理舊數據

**警告：** 只有在確認新架構運作正常後才執行清理！

```swift
func cleanupOldData() async throws {
    // 1. 標記舊課程為已遷移（不要直接刪除）
    let snapshot = try await db.collection("organizations")
        .whereField("type", isEqualTo: "course")
        .getDocuments()
    
    for document in snapshot.documents {
        try await document.reference.updateData([
            "isMigrated": true,
            "migratedAt": Timestamp(date: Date())
        ])
    }
    
    print("✅ 已標記 \(snapshot.documents.count) 個課程為已遷移")
    
    // 實際刪除可以在確認一切正常後手動執行
}
```

---

## 📝 遷移後檢查項目

### 必檢項目

- [ ] 所有課程都出現在新系統
- [ ] 教師角色正確映射
- [ ] 學生可以看到自己的課程
- [ ] 選課代碼功能正常
- [ ] 課表資訊正確
- [ ] 無數據遺失

### 建議檢查

- [ ] 課程封面圖片
- [ ] 課程描述和大綱
- [ ] 歷史選課記錄
- [ ] 課程統計資料

---

## ⏮️ 回滾計劃

如果遷移出現問題：

1. **立即停止遷移**
2. **恢復 Firestore 備份**
3. **檢查錯誤日誌**
4. **修正遷移腳本**
5. **在測試環境重新測試**

---

## 💡 最佳實踐

1. **分批遷移**：不要一次遷移所有數據，可以按學期或系所分批
2. **保留日誌**：記錄每個遷移操作，便於追蹤問題
3. **並行運行**：讓新舊系統並存一段時間
4. **用戶溝通**：提前通知用戶系統升級
5. **監控指標**：設置監控，及時發現問題

---

## 🆘 常見問題

### Q: 遷移需要多長時間？
A: 取決於數據量，一般每1000條記錄約需1-2分鐘。

### Q: 遷移失敗怎麼辦？
A: 使用 Firestore 備份回滾，檢查錯誤日誌後重試。

### Q: 可以保留舊數據嗎？
A: 可以，建議至少保留3-6個月作為備份。

### Q: 角色映射不準確怎麼辦？
A: 可以在遷移後手動調整，使用 EnrollmentManagementView。

---

## 📞 技術支援

如果遇到問題，請查看：
- `REFACTOR_PLAN.md` - 架構設計文檔
- `INTEGRATION_GUIDE.md` - 整合指南
- GitHub Issues

---

**最後更新：** 2025-12-01
**版本：** 1.0.0
