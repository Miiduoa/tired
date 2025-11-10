import Foundation
import FirebaseFirestore

// MARK: - Base Firestore Service
/// 提供通用的 Firestore CRUD 操作
class BaseFirestoreService {

    let db: Firestore

    init() {
        self.db = Firestore.firestore()
    }

    // MARK: - Generic CRUD Operations

    /// Create a document
    func create<T: Codable & Identifiable>(
        _ item: T,
        collection: String
    ) async throws where T.ID == String {
        try db.collection(collection).document(item.id).setData(from: item)
    }

    /// Read a document by ID
    func read<T: Codable>(
        id: String,
        collection: String,
        as type: T.Type
    ) async throws -> T? {
        let snapshot = try await db.collection(collection).document(id).getDocument()
        return try snapshot.data(as: T.self)
    }

    /// Update a document
    func update<T: Codable & Identifiable>(
        _ item: T,
        collection: String
    ) async throws where T.ID == String {
        try db.collection(collection).document(item.id).setData(from: item, merge: true)
    }

    /// Delete a document (soft delete by setting deleted_at)
    func softDelete(
        id: String,
        collection: String
    ) async throws {
        try await db.collection(collection).document(id).updateData([
            "deletedAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// Delete a document (hard delete)
    func hardDelete(
        id: String,
        collection: String
    ) async throws {
        try await db.collection(collection).document(id).delete()
    }

    // MARK: - Query Operations

    /// Query documents with filters
    func query<T: Codable>(
        collection: String,
        filters: [QueryFilter],
        orderBy: [(field: String, descending: Bool)] = [],
        limit: Int? = nil,
        as type: T.Type
    ) async throws -> [T] {
        var query: Query = db.collection(collection)

        // Apply filters
        for filter in filters {
            query = applyFilter(query, filter: filter)
        }

        // Apply ordering
        for order in orderBy {
            query = query.order(by: order.field, descending: order.descending)
        }

        // Apply limit
        if let limit = limit {
            query = query.limit(to: limit)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: T.self) }
    }

    /// Listen to a collection with filters (real-time)
    func listen<T: Codable>(
        collection: String,
        filters: [QueryFilter],
        orderBy: [(field: String, descending: Bool)] = [],
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        var query: Query = db.collection(collection)

        // Apply filters
        for filter in filters {
            query = applyFilter(query, filter: filter)
        }

        // Apply ordering
        for order in orderBy {
            query = query.order(by: order.field, descending: order.descending)
        }

        return query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                print("Error listening to collection: \(error?.localizedDescription ?? "unknown")")
                return
            }

            let items = snapshot.documents.compactMap { doc -> T? in
                try? doc.data(as: T.self)
            }

            onChange(items)
        }
    }

    // MARK: - Batch Operations

    /// Batch write multiple operations
    func batchWrite(operations: [(collection: String, id: String, data: [String: Any])]) async throws {
        let batch = db.batch()

        for operation in operations {
            let ref = db.collection(operation.collection).document(operation.id)
            batch.setData(operation.data, forDocument: ref, merge: true)
        }

        try await batch.commit()
    }

    // MARK: - Helper Methods

    private func applyFilter(_ query: Query, filter: QueryFilter) -> Query {
        switch filter {
        case .equals(let field, let value):
            return query.whereField(field, isEqualTo: value)
        case .notEquals(let field, let value):
            return query.whereField(field, isNotEqualTo: value)
        case .lessThan(let field, let value):
            return query.whereField(field, isLessThan: value)
        case .lessThanOrEquals(let field, let value):
            return query.whereField(field, isLessThanOrEqualTo: value)
        case .greaterThan(let field, let value):
            return query.whereField(field, isGreaterThan: value)
        case .greaterThanOrEquals(let field, let value):
            return query.whereField(field, isGreaterThanOrEqualTo: value)
        case .arrayContains(let field, let value):
            return query.whereField(field, arrayContains: value)
        case .arrayContainsAny(let field, let values):
            return query.whereField(field, arrayContainsAny: values)
        case .inArray(let field, let values):
            return query.whereField(field, in: values)
        case .notInArray(let field, let values):
            return query.whereField(field, notIn: values)
        case .isNull(let field):
            return query.whereField(field, isEqualTo: NSNull())
        }
    }
}

// MARK: - Query Filter
enum QueryFilter {
    case equals(field: String, value: Any)
    case notEquals(field: String, value: Any)
    case lessThan(field: String, value: Any)
    case lessThanOrEquals(field: String, value: Any)
    case greaterThan(field: String, value: Any)
    case greaterThanOrEquals(field: String, value: Any)
    case arrayContains(field: String, value: Any)
    case arrayContainsAny(field: String, values: [Any])
    case inArray(field: String, values: [Any])
    case notInArray(field: String, values: [Any])
    case isNull(field: String)
}
