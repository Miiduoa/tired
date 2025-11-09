import Foundation
import FirebaseFirestore

// MARK: - Task Category
enum TaskCategory: String, Codable, CaseIterable {
    case school = "school"
    case work = "work"
    case personal = "personal"
    case other = "other"
}

// MARK: - Task Priority
enum TaskPriority: String, Codable, CaseIterable {
    case P0 = "P0"
    case P1 = "P1"
    case P2 = "P2"
    case P3 = "P3"

    var sortOrder: Int {
        switch self {
        case .P0: return 0
        case .P1: return 1
        case .P2: return 2
        case .P3: return 3
        }
    }
}

// MARK: - Task State
enum TaskState: String, Codable {
    case open = "open"
    case done = "done"
    case skipped = "skipped"
}

// MARK: - Energy Level
enum EnergyLevel: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

// MARK: - Task Evidence
struct TaskEvidence: Codable, Identifiable {
    var id: String
    var type: EvidenceType
    var title: String
    var url: String?
    var fileId: String?
    var note: String?

    enum EvidenceType: String, Codable {
        case link = "link"
        case file = "file"
        case note = "note"
    }

    init(id: String = UUID().uuidString, type: EvidenceType, title: String, url: String? = nil, fileId: String? = nil, note: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.url = url
        self.fileId = fileId
        self.note = note
    }
}

// MARK: - Work Session
struct WorkSession: Codable, Identifiable {
    var id: String
    var startAt: Date
    var endAt: Date
    var durationMin: Int
    var pomodoroCount: Int
    var breakSessions: Int
    var wasInterrupted: Bool

    init(id: String = UUID().uuidString, startAt: Date, endAt: Date, durationMin: Int, pomodoroCount: Int = 0, breakSessions: Int = 0, wasInterrupted: Bool = false) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.durationMin = durationMin
        self.pomodoroCount = pomodoroCount
        self.breakSessions = breakSessions
        self.wasInterrupted = wasInterrupted
    }
}

// MARK: - Task Model
struct Task: Codable, Identifiable {
    var id: String
    var userId: String

    // Basic Info
    var title: String
    var description: String
    var sourceType: String // 'user' for Phase 0.0a
    var sourceContext: String

    // Categorization
    var category: TaskCategory
    var termId: String?
    var peopleNote: String?
    var courseId: String?

    // Scheduling
    var deadlineAt: Date?
    var deadlineDate: String? // 'YYYY-MM-DD' denormalized field
    var plannedWorkDate: Date?
    var firstPlannedDate: Date?

    // Priority & Focus
    var priority: TaskPriority
    var isTodayFocus: Bool
    var isCrossTermImportant: Bool

    // Status Flags
    var isInbox: Bool
    var isDateLocked: Bool // manual scheduling lock

    // State
    var state: TaskState
    var doneAt: Date?
    var skippedAt: Date?
    var deletedAt: Date?

    // Effort Estimation
    var estimatedEffortMin: Int
    var labels: [String]

    // Evidence & Work Tracking
    var evidences: [TaskEvidence]
    var actualWorkMin: Int?
    var workSessions: [WorkSession]

    // Dependencies
    var blockedByTaskIds: [String]
    var blockingTaskIds: [String]

    // Energy
    var energyRequired: EnergyLevel?

    // Week Planning
    var postponeToNextWeekCount: Int
    var committedWeekStartDate: Date?
    var lastAutoplanWeekStart: Date?

    // Exam Prep
    var isExamPrep: Bool
    var examPrepGroupId: String?
    var examPrepSessionNumber: Int?
    var examPrepTotalSessions: Int?
    var examEventDeleted: Bool?

    // Template & Series
    var templateId: String?
    var groupSeriesId: String?

    // Sync Status (for offline support)
    var syncStatus: SyncStatus
    var localUpdatedAt: Date

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    enum SyncStatus: String, Codable {
        case synced = "synced"
        case pending = "pending"
        case conflict = "conflict"
    }

    // MARK: - Initializer
    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        description: String = "",
        sourceType: String = "user",
        sourceContext: String = "",
        category: TaskCategory,
        termId: String? = nil,
        peopleNote: String? = nil,
        courseId: String? = nil,
        deadlineAt: Date? = nil,
        deadlineDate: String? = nil,
        plannedWorkDate: Date? = nil,
        firstPlannedDate: Date? = nil,
        priority: TaskPriority = .P2,
        isTodayFocus: Bool = false,
        isCrossTermImportant: Bool = false,
        isInbox: Bool = true,
        isDateLocked: Bool = false,
        state: TaskState = .open,
        doneAt: Date? = nil,
        skippedAt: Date? = nil,
        deletedAt: Date? = nil,
        estimatedEffortMin: Int = 30,
        labels: [String] = [],
        evidences: [TaskEvidence] = [],
        actualWorkMin: Int? = nil,
        workSessions: [WorkSession] = [],
        blockedByTaskIds: [String] = [],
        blockingTaskIds: [String] = [],
        energyRequired: EnergyLevel? = nil,
        postponeToNextWeekCount: Int = 0,
        committedWeekStartDate: Date? = nil,
        lastAutoplanWeekStart: Date? = nil,
        isExamPrep: Bool = false,
        examPrepGroupId: String? = nil,
        examPrepSessionNumber: Int? = nil,
        examPrepTotalSessions: Int? = nil,
        examEventDeleted: Bool? = nil,
        templateId: String? = nil,
        groupSeriesId: String? = nil,
        syncStatus: SyncStatus = .synced,
        localUpdatedAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.sourceType = sourceType
        self.sourceContext = sourceContext
        self.category = category
        self.termId = termId
        self.peopleNote = peopleNote
        self.courseId = courseId
        self.deadlineAt = deadlineAt
        self.deadlineDate = deadlineDate
        self.plannedWorkDate = plannedWorkDate
        self.firstPlannedDate = firstPlannedDate
        self.priority = priority
        self.isTodayFocus = isTodayFocus
        self.isCrossTermImportant = isCrossTermImportant
        self.isInbox = isInbox
        self.isDateLocked = isDateLocked
        self.state = state
        self.doneAt = doneAt
        self.skippedAt = skippedAt
        self.deletedAt = deletedAt
        self.estimatedEffortMin = estimatedEffortMin
        self.labels = labels
        self.evidences = evidences
        self.actualWorkMin = actualWorkMin
        self.workSessions = workSessions
        self.blockedByTaskIds = blockedByTaskIds
        self.blockingTaskIds = blockingTaskIds
        self.energyRequired = energyRequired
        self.postponeToNextWeekCount = postponeToNextWeekCount
        self.committedWeekStartDate = committedWeekStartDate
        self.lastAutoplanWeekStart = lastAutoplanWeekStart
        self.isExamPrep = isExamPrep
        self.examPrepGroupId = examPrepGroupId
        self.examPrepSessionNumber = examPrepSessionNumber
        self.examPrepTotalSessions = examPrepTotalSessions
        self.examEventDeleted = examEventDeleted
        self.templateId = templateId
        self.groupSeriesId = groupSeriesId
        self.syncStatus = syncStatus
        self.localUpdatedAt = localUpdatedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Task Helpers
extension Task {
    // Check if task is blocked by other open tasks
    func isBlocked(allTasks: [Task]) -> Bool {
        guard !blockedByTaskIds.isEmpty else { return false }

        let validBlocking = blockedByTaskIds.compactMap { id in
            allTasks.first { $0.id == id && $0.deletedAt == nil && $0.state == .open }
        }

        return !validBlocking.isEmpty
    }

    // Get blocking tasks info
    func getBlockingTasksInfo(allTasks: [Task]) -> (validTasks: [Task], openTasks: [Task], completedTasks: [Task], hasDeleted: Bool, deletedCount: Int) {
        let allIds = blockedByTaskIds
        let tasks = allIds.compactMap { id in allTasks.first { $0.id == id } }
        let valid = tasks.filter { $0.deletedAt == nil }
        let deletedCount = allIds.count - valid.count

        return (
            validTasks: valid,
            openTasks: valid.filter { $0.state == .open },
            completedTasks: valid.filter { $0.state == .done },
            hasDeleted: deletedCount > 0,
            deletedCount: deletedCount
        )
    }

    // Check if task has dependents
    func hasDependents() -> Bool {
        return !blockingTaskIds.isEmpty
    }

    // Calculate actual effort for scheduling
    func effortForScheduling() -> Int {
        if let actual = actualWorkMin, actual > 0 {
            return min(max(actual, 15), 240)
        }
        return estimatedEffortMin
    }

    // Should show exam prep suggestion
    func shouldShowExamPrepSuggestion() -> Bool {
        return estimatedEffortMin >= 240 &&
               category == .school &&
               deadlineAt != nil &&
               !isExamPrep
    }
}
