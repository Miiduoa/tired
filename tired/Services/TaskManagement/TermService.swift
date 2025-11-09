import Foundation
import FirebaseFirestore

// MARK: - Term Service
@MainActor
class TermService: BaseFirestoreService, ObservableObject {

    static let shared = TermService()

    private let COLLECTION = "term_configs"

    @Published var currentTerm: TermConfig?
    @Published var allTerms: [TermConfig] = []

    // MARK: - CRUD Operations

    func createTerm(_ term: TermConfig) async throws {
        var newTerm = term
        newTerm.createdAt = Date()
        newTerm.updatedAt = Date()

        try await create(newTerm, collection: COLLECTION)
    }

    func updateTerm(_ term: TermConfig) async throws {
        var updatedTerm = term
        updatedTerm.updatedAt = Date()

        try await update(updatedTerm, collection: COLLECTION)
    }

    func getTerm(id: String) async throws -> TermConfig? {
        return try await read(id: id, collection: COLLECTION, as: TermConfig.self)
    }

    func getTermByTermId(userId: String, termId: String) async throws -> TermConfig? {
        let terms = try await query(
            collection: COLLECTION,
            filters: [
                .equals(field: "userId", value: userId),
                .equals(field: "termId", value: termId)
            ],
            limit: 1,
            as: TermConfig.self
        )
        return terms.first
    }

    func getAllTerms(userId: String) async throws -> [TermConfig] {
        return try await query(
            collection: COLLECTION,
            filters: [.equals(field: "userId", value: userId)],
            orderBy: [("createdAt", true)],
            as: TermConfig.self
        )
    }

    // MARK: - Term Creation Helpers

    func createAcademicTerm(
        userId: String,
        year: String,
        semester: String,
        startDate: Date,
        endDate: Date
    ) async throws -> TermConfig {
        let termId = "\(year)-\(semester)"

        let term = TermConfig(
            userId: userId,
            termId: termId,
            startDate: startDate,
            endDate: endDate,
            isHolidayPeriod: false
        )

        try await createTerm(term)
        return term
    }

    func createHolidayTerm(
        userId: String,
        year: String,
        type: String, // "summer" or "winter"
        startDate: Date,
        endDate: Date
    ) async throws -> TermConfig {
        let termId = "\(year)-\(type)"

        let term = TermConfig(
            userId: userId,
            termId: termId,
            startDate: startDate,
            endDate: endDate,
            isHolidayPeriod: true
        )

        try await createTerm(term)
        return term
    }

    func createPersonalDefaultTerm(userId: String) async throws -> TermConfig {
        let term = TermConfig(
            userId: userId,
            termId: "personal-default",
            startDate: Date(),
            endDate: nil,
            isHolidayPeriod: true
        )

        try await createTerm(term)
        return term
    }

    // MARK: - Term Management

    func switchTerm(
        userId: String,
        newTermId: String,
        profile: UserProfile,
        profileService: UserProfileService
    ) async throws {
        guard let newTerm = try await getTermByTermId(userId: userId, termId: newTermId) else {
            throw TermError.termNotFound
        }

        var updatedProfile = profile
        updatedProfile.previousTermId = profile.currentTermId
        updatedProfile.currentTermId = newTermId
        updatedProfile.lastTermChangeAt = Date()

        try await profileService.updateProfile(updatedProfile)
    }

    func markTermCleanupHandled(profile: UserProfile, profileService: UserProfileService) async throws {
        var updatedProfile = profile
        updatedProfile.lastTermCleanupHandledAt = Date()

        try await profileService.updateProfile(updatedProfile)
    }

    // MARK: - Term Queries

    func getActiveTerm(userId: String, on date: Date = Date()) async throws -> TermConfig? {
        let allTerms = try await getAllTerms(userId: userId)
        return allTerms.first { $0.isActive(on: date) }
    }

    func needsTermCleanup(profile: UserProfile) -> Bool {
        guard let previousTermId = profile.previousTermId,
              let lastTermChangeAt = profile.lastTermChangeAt else {
            return false
        }

        // Check if cleanup has been handled
        if let lastHandled = profile.lastTermCleanupHandledAt,
           lastHandled >= lastTermChangeAt {
            return false
        }

        // Check if there was a term change
        return previousTermId != profile.currentTermId
    }
}

// MARK: - Term Error
enum TermError: Error, LocalizedError {
    case termNotFound
    case invalidTermId
    case termAlreadyExists

    var errorDescription: String? {
        switch self {
        case .termNotFound:
            return "找不到學期"
        case .invalidTermId:
            return "無效的學期 ID"
        case .termAlreadyExists:
            return "學期已存在"
        }
    }
}
