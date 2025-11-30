import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

/// 成績管理服務 - Moodle 級別的精細功能
class GradeService: ObservableObject {
    private let db = FirebaseManager.shared.db
    
    // MARK: - Grade CRUD
    
    /// 創建成績
    func createGrade(_ grade: Grade) async throws -> Grade {
        var newGrade = grade
        newGrade.updatedAt = Date()
        
        // 自動計算百分比
        if newGrade.percentage == nil, let score = newGrade.score {
            newGrade.percentage = (score / newGrade.maxScore) * 100
        }
        
        // 如果未設定等級，根據百分比自動計算
        if newGrade.grade == nil, let percentage = newGrade.percentage {
            newGrade.grade = LetterGrade.fromPercentage(percentage)
        }
        
        let docRef = try db.collection("grades").addDocument(from: newGrade)
        var createdGrade = newGrade
        createdGrade.id = docRef.documentID
        return createdGrade
    }
    
    /// 更新成績
    func updateGrade(gradeId: String, score: Double? = nil, grade: LetterGrade? = nil, isPass: Bool? = nil, feedback: String? = nil, rubricScores: [RubricScore]? = nil, isReleased: Bool? = nil) async throws {
        let gradeRef = db.collection("grades").document(gradeId)
        
        // 先獲取現有成績以計算百分比
        let currentGrade = try await gradeRef.getDocument().data(as: Grade.self)
        
        var updates: [String: Any] = [
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let score = score {
            updates["score"] = score
            updates["percentage"] = (score / currentGrade.maxScore) * 100
            
            // 自動計算等級
            if grade == nil {
                updates["grade"] = LetterGrade.fromPercentage((score / currentGrade.maxScore) * 100).rawValue
            }
        }
        
        if let grade = grade {
            updates["grade"] = grade.rawValue
        }
        
        if let isPass = isPass {
            updates["isPass"] = isPass
        }
        
        if let feedback = feedback {
            updates["feedback"] = feedback
        }
        
        if let rubricScores = rubricScores {
            updates["rubricScores"] = try rubricScores.map { try Firestore.Encoder().encode($0) }
        }
        
        if let isReleased = isReleased {
            updates["isReleased"] = isReleased
        }
        
        // 如果已評分，更新狀態和時間
        if score != nil || grade != nil || isPass != nil {
            updates["status"] = GradeStatus.graded.rawValue
            updates["gradedAt"] = Timestamp(date: Date())
        }
        
        try await gradeRef.updateData(updates)
    }
    
    /// 刪除成績
    func deleteGrade(gradeId: String) async throws {
        try await db.collection("grades").document(gradeId).delete()
    }
    
    /// 獲取單個成績
    func getGrade(gradeId: String) async throws -> Grade {
        let doc = try await db.collection("grades").document(gradeId).getDocument()
        return try doc.data(as: Grade.self)
    }
    
    // MARK: - Grade Queries
    
    /// 獲取學員的所有成績（實時監聽）
    func getStudentGrades(userId: String, organizationId: String) -> AnyPublisher<[Grade], Error> {
        let subject = PassthroughSubject<[Grade], Error>()
        
        db.collection("grades")
            .whereField("userId", isEqualTo: userId)
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                let grades = documents.compactMap { doc -> Grade? in
                    try? doc.data(as: Grade.self)
                }
                
                subject.send(grades)
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// 獲取任務的成績
    func getTaskGrade(taskId: String) async throws -> Grade? {
        let snapshot = try await db.collection("grades")
            .whereField("taskId", isEqualTo: taskId)
            .limit(to: 1)
            .getDocuments()
        
        return try snapshot.documents.first?.data(as: Grade.self)
    }
    
    /// 獲取課程的所有成績（用於教師查看）
    func getCourseGrades(organizationId: String, gradeItemId: String? = nil) -> AnyPublisher<[Grade], Error> {
        let subject = PassthroughSubject<[Grade], Error>()
        
        var query: Query = db.collection("grades")
            .whereField("organizationId", isEqualTo: organizationId)
        
        if let gradeItemId = gradeItemId {
            query = query.whereField("gradeItemId", isEqualTo: gradeItemId)
        }
        
        query.order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                let grades = documents.compactMap { doc -> Grade? in
                    try? doc.data(as: Grade.self)
                }
                
                subject.send(grades)
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// 批量創建成績（用於批量評分）
    func createGrades(_ grades: [Grade]) async throws -> [Grade] {
        let batch = db.batch()
        var createdGrades: [Grade] = []
        
        for grade in grades {
            let docRef = db.collection("grades").document()
            var newGrade = grade
            newGrade.id = docRef.documentID
            newGrade.updatedAt = Date()
            
            // 自動計算百分比和等級
            if newGrade.percentage == nil, let score = newGrade.score {
                newGrade.percentage = (score / newGrade.maxScore) * 100
            }
            if newGrade.grade == nil, let percentage = newGrade.percentage {
                newGrade.grade = LetterGrade.fromPercentage(percentage)
            }
            
            try batch.setData(from: newGrade, forDocument: docRef)
            createdGrades.append(newGrade)
        }
        
        try await batch.commit()
        return createdGrades
    }
    
    // MARK: - Grade Calculation
    
    /// 計算學員的總成績
    func calculateFinalGrade(userId: String, organizationId: String) async throws -> GradeSummary {
        // 獲取所有成績項目
        let gradeItemsSnapshot = try await db.collection("gradeItems")
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
        
        let gradeItems = try gradeItemsSnapshot.documents.compactMap { doc -> GradeItem? in
            try? doc.data(as: GradeItem.self)
        }
        
        // 獲取學員的所有成績
        let gradesSnapshot = try await db.collection("grades")
            .whereField("userId", isEqualTo: userId)
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
        
        let grades = try gradesSnapshot.documents.compactMap { doc -> Grade? in
            try? doc.data(as: Grade.self)
        }
        
        // 計算各項成績摘要
        var gradeItemSummaries: [GradeSummary.GradeItemSummary] = []
        var totalWeightedScore: Double = 0
        var totalWeight: Double = 0
        
        for gradeItem in gradeItems {
            let grade = grades.first { $0.gradeItemId == gradeItem.id }
            
            let percentage = grade?.calculatedPercentage
            let weightedScore = percentage != nil ? (percentage! * gradeItem.weight / 100) : nil
            
            if let weightedScore = weightedScore {
                totalWeightedScore += weightedScore
            }
            totalWeight += gradeItem.weight
            
            gradeItemSummaries.append(GradeSummary.GradeItemSummary(
                id: gradeItem.id ?? "",
                name: gradeItem.name,
                score: grade?.score,
                maxScore: gradeItem.maxScore,
                percentage: percentage,
                weight: gradeItem.weight,
                weightedScore: weightedScore
            ))
        }
        
        // 計算總成績
        let finalPercentage = totalWeight > 0 ? (totalWeightedScore / totalWeight * 100) : nil
        let finalGrade = finalPercentage != nil ? LetterGrade.fromPercentage(finalPercentage!) : nil
        
        return GradeSummary(
            userId: userId,
            organizationId: organizationId,
            finalScore: nil, // 總分不適用於加權計算
            finalPercentage: finalPercentage,
            finalGrade: finalGrade,
            gradeItems: gradeItemSummaries
        )
    }
    
    // MARK: - Grade Statistics
    
    /// 獲取成績統計
    func getGradeStatistics(organizationId: String, gradeItemId: String? = nil) async throws -> GradeStatistics {
        var query: Query = db.collection("grades")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("status", isEqualTo: GradeStatus.graded.rawValue)
        
        if let gradeItemId = gradeItemId {
            query = query.whereField("gradeItemId", isEqualTo: gradeItemId)
        }
        
        let snapshot = try await query.getDocuments()
        let grades = try snapshot.documents.compactMap { doc -> Grade? in
            try? doc.data(as: Grade.self)
        }
        
        guard !grades.isEmpty else {
            return GradeStatistics(
                organizationId: organizationId,
                totalStudents: 0,
                gradedCount: 0,
                averageScore: nil,
                medianScore: nil,
                highestScore: nil,
                lowestScore: nil,
                passRate: nil,
                distribution: []
            )
        }
        
        // 獲取唯一學員數
        let uniqueUserIds = Set(grades.map { $0.userId })
        let totalStudents = uniqueUserIds.count
        
        // 計算統計數據
        let percentages = grades.compactMap { $0.calculatedPercentage }
        let scores = grades.compactMap { $0.score }
        
        let averageScore = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        let averagePercentage = percentages.isEmpty ? nil : percentages.reduce(0, +) / Double(percentages.count)
        
        let sortedPercentages = percentages.sorted()
        let medianScore = sortedPercentages.isEmpty ? nil : (sortedPercentages.count % 2 == 0 ?
            (sortedPercentages[sortedPercentages.count / 2 - 1] + sortedPercentages[sortedPercentages.count / 2]) / 2 :
            sortedPercentages[sortedPercentages.count / 2])
        
        let highestScore = percentages.max()
        let lowestScore = percentages.min()
        
        // 計算通過率（假設 60 分為及格）
        let passCount = percentages.filter { $0 >= 60 }.count
        let passRate = percentages.isEmpty ? nil : Double(passCount) / Double(percentages.count) * 100
        
        // 計算成績分布
        var distribution: [GradeStatistics.GradeDistribution] = []
        for letterGrade in LetterGrade.allCases {
            let count = percentages.filter { LetterGrade.fromPercentage($0) == letterGrade }.count
            let percentage = percentages.isEmpty ? 0 : Double(count) / Double(percentages.count) * 100
            distribution.append(GradeStatistics.GradeDistribution(
                grade: letterGrade,
                count: count,
                percentage: percentage
            ))
        }
        
        return GradeStatistics(
            organizationId: organizationId,
            totalStudents: totalStudents,
            gradedCount: grades.count,
            averageScore: averageScore ?? averagePercentage,
            medianScore: medianScore,
            highestScore: highestScore,
            lowestScore: lowestScore,
            passRate: passRate,
            distribution: distribution
        )
    }
    
    // MARK: - Grade Item Management
    
    /// 創建成績項目
    func createGradeItem(_ item: GradeItem) async throws -> GradeItem {
        var newItem = item
        newItem.updatedAt = Date()
        let docRef = try db.collection("gradeItems").addDocument(from: newItem)
        var createdItem = newItem
        createdItem.id = docRef.documentID
        return createdItem
    }
    
    /// 獲取課程的所有成績項目
    func getGradeItems(organizationId: String) -> AnyPublisher<[GradeItem], Error> {
        let subject = PassthroughSubject<[GradeItem], Error>()
        
        db.collection("gradeItems")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }
                
                let items = documents.compactMap { doc -> GradeItem? in
                    try? doc.data(as: GradeItem.self)
                }
                
                subject.send(items)
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// 更新成績項目
    func updateGradeItem(itemId: String, updates: [String: Any]) async throws {
        var finalUpdates = updates
        finalUpdates["updatedAt"] = Timestamp(date: Date())
        try await db.collection("gradeItems").document(itemId).updateData(finalUpdates)
    }
    
    /// 刪除成績項目
    func deleteGradeItem(itemId: String) async throws {
        try await db.collection("gradeItems").document(itemId).delete()
    }
    
    // MARK: - Grade Category Management
    
    /// 創建成績分類
    func createGradeCategory(_ category: GradeCategory) async throws -> GradeCategory {
        var newCategory = category
        newCategory.updatedAt = Date()
        let docRef = try db.collection("gradeCategories").addDocument(from: newCategory)
        var createdCategory = newCategory
        createdCategory.id = docRef.documentID
        return createdCategory
    }
    
    /// 獲取課程的所有成績分類
    func getGradeCategories(organizationId: String) async throws -> [GradeCategory] {
        let snapshot = try await db.collection("gradeCategories")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc -> GradeCategory? in
            try? doc.data(as: GradeCategory.self)
        }
    }
}

