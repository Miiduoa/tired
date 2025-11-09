import Foundation
import FirebaseFirestore

struct Task: Codable, Identifiable {
    var id: String = UUID().uuidString
    var userId: String

    var title: String
    var description: String
    var sourceType: String = "user"
    var sourceContext: String

    var category: TaskCategory
    var termId: String?
    var peopleNote: String?

    var courseId: String?

    var deadlineAt: Date?
    var deadlineDate: String?  // YYYY-MM-DD denormalized
    var plannedWorkDate: Date?
    var firstPlannedDate: Date?

    var priority: Priority
    var isTodayFocus: Bool
    var isCrossTermImportant: Bool

    var isInbox: Bool
    var isDateLocked: Bool

    var state: TaskState
    var doneAt: Date?
    var skippedAt: Date?
    var deletedAt: Date?

    var estimatedEffortMin: Int
    var labels: [String]

    var evidences: [TaskEvidence]

    var actualWorkMin: Int?
    var workSessions: [WorkSession]

    var blockedByTaskIds: [String]
    var blockingTaskIds: [String]

    var energyRequired: EnergyLevel?

    var postponeToNextWeekCount: Int
    var committedWeekStartDate: Date?
    var lastAutoplanWeekStart: Date?

    var isExamPrep: Bool
    var examPrepGroupId: String?
    var examPrepSessionNumber: Int?
    var examPrepTotalSessions: Int?
    var examEventDeleted: Bool?

    var templateId: String?
    var groupSeriesId: String?

    var syncStatus: SyncStatus
    var localUpdatedAt: Date

    var createdAt: Date
    var updatedAt: Date

    enum TaskCategory: String, Codable {
        case school
        case work
        case personal
        case other
    }

    enum Priority: String, Codable {
        case P0, P1, P2, P3
    }

    enum TaskState: String, Codable {
        case open
        case done
        case skipped
    }

    enum EnergyLevel: String, Codable {
        case high
        case medium
        case low
    }

    enum SyncStatus: String, Codable {
        case synced
        case pending
        case conflict
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case sourceType = "source_type"
        case sourceContext = "source_context"
        case category
        case termId = "term_id"
        case peopleNote = "people_note"
        case courseId = "course_id"
        case deadlineAt = "deadline_at"
        case deadlineDate = "deadline_date"
        case plannedWorkDate = "planned_work_date"
        case firstPlannedDate = "first_planned_date"
        case priority
        case isTodayFocus = "is_today_focus"
        case isCrossTermImportant = "is_cross_term_important"
        case isInbox = "is_inbox"
        case isDateLocked = "is_date_locked"
        case state
        case doneAt = "done_at"
        case skippedAt = "skipped_at"
        case deletedAt = "deleted_at"
        case estimatedEffortMin = "estimated_effort_min"
        case labels
        case evidences
        case actualWorkMin = "actual_work_min"
        case workSessions = "work_sessions"
        case blockedByTaskIds = "blocked_by_task_ids"
        case blockingTaskIds = "blocking_task_ids"
        case energyRequired = "energy_required"
        case postponeToNextWeekCount = "postpone_to_next_week_count"
        case committedWeekStartDate = "committed_week_start_date"
        case lastAutoplanWeekStart = "last_autoplan_week_start"
        case isExamPrep = "is_exam_prep"
        case examPrepGroupId = "exam_prep_group_id"
        case examPrepSessionNumber = "exam_prep_session_number"
        case examPrepTotalSessions = "exam_prep_total_sessions"
        case examEventDeleted = "exam_event_deleted"
        case templateId = "template_id"
        case groupSeriesId = "group_series_id"
        case syncStatus = "_sync_status"
        case localUpdatedAt = "_local_updated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String = UUID().uuidString, userId: String, title: String, description: String = "", category: TaskCategory, termId: String? = nil, priority: Priority = .P2) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.sourceContext = ""
        self.category = category
        self.termId = termId
        self.priority = priority
        self.isTodayFocus = false
        self.isCrossTermImportant = false
        self.isInbox = true
        self.isDateLocked = false
        self.state = .open
        self.estimatedEffortMin = 30
        self.labels = []
        self.evidences = []
        self.workSessions = []
        self.blockedByTaskIds = []
        self.blockingTaskIds = []
        self.postponeToNextWeekCount = 0
        self.isExamPrep = false
        self.syncStatus = .synced
        let now = Date()
        self.localUpdatedAt = now
        self.createdAt = now
        self.updatedAt = now
    }
}
