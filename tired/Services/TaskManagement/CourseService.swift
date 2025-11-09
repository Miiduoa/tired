import Foundation
import FirebaseFirestore

// MARK: - Course Service
@MainActor
class CourseService: BaseFirestoreService, ObservableObject {

    static let shared = CourseService()

    private let COLLECTION = "courses"

    @Published var courses: [Course] = []

    // MARK: - CRUD Operations

    func createCourse(_ course: Course) async throws {
        var newCourse = course
        newCourse.createdAt = Date()
        newCourse.updatedAt = Date()

        try await create(newCourse, collection: COLLECTION)
    }

    func updateCourse(_ course: Course) async throws {
        var updatedCourse = course
        updatedCourse.updatedAt = Date()

        try await update(updatedCourse, collection: COLLECTION)
    }

    func getCourse(id: String) async throws -> Course? {
        return try await read(id: id, collection: COLLECTION, as: Course.self)
    }

    func deleteCourse(id: String) async throws {
        try await hardDelete(id: id, collection: COLLECTION)
    }

    // MARK: - Query Courses

    func getCourses(userId: String, termId: String) async throws -> [Course] {
        return try await query(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .equals(field: "termId", value: termId)
            ],
            orderBy: [("name", false)],
            as: Course.self
        )
    }

    func getAllCourses(userId: String) async throws -> [Course] {
        return try await query(
            collection: COLLECTION,
            filters: [.equals(field: "userId", value: userId)],
            orderBy: [("createdAt", true)],
            as: Course.self
        )
    }

    // MARK: - Listen to Courses (Real-time)

    private var listener: ListenerRegistration?

    func listenToCourses(userId: String, termId: String, onChange: @escaping ([Course]) -> Void) {
        listener?.remove()

        listener = listen(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .equals(field: "termId", value: termId)
            ],
            orderBy: [("name", false)],
            onChange: onChange
        )
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Course Management

    func getTasksForCourse(courseId: String, userId: String) async throws -> [Task] {
        let tasks = try await TaskService.shared.getTasks(
            userId: userId,
            filters: [
                .equals(field: "courseId", value: courseId),
                .isNull(field: "deletedAt")
            ]
        )
        return tasks
    }

    func getCompletedTasksForCourse(courseId: String, userId: String) async throws -> [Task] {
        let tasks = try await TaskService.shared.getTasks(
            userId: userId,
            filters: [
                .equals(field: "courseId", value: courseId),
                .equals(field: "state", value: "done"),
                .isNull(field: "deletedAt")
            ]
        )
        return tasks
    }
}
