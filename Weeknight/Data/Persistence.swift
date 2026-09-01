import Foundation
import SwiftData

@Model
final class PersistentAppState {
    @Attribute(.unique) var key: String
    var schemaVersion: Int
    var payload: Data

    init(key: String = "primary", schemaVersion: Int, payload: Data) {
        self.key = key
        self.schemaVersion = schemaVersion
        self.payload = payload
    }
}

enum PersistenceError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "Saved data uses unsupported schema version \(version)."
        }
    }
}

@MainActor
protocol AppStatePersistence: AnyObject {
    func load() throws -> AppSnapshot?
    func save(_ snapshot: AppSnapshot) throws
    func reset(to snapshot: AppSnapshot) throws
    func recordCount() throws -> Int
}

@MainActor
final class SwiftDataAppStatePersistence: AppStatePersistence {
    private let context: ModelContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(container: ModelContainer) {
        context = ModelContext(container)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    convenience init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: PersistentAppState.self, configurations: configuration)
        self.init(container: container)
    }

    func load() throws -> AppSnapshot? {
        guard let record = try records().first else { return nil }
        guard (1...AppSnapshot.currentSchemaVersion).contains(record.schemaVersion) else {
            throw PersistenceError.unsupportedSchema(record.schemaVersion)
        }
        var snapshot = try decoder.decode(AppSnapshot.self, from: record.payload)
        guard (1...AppSnapshot.currentSchemaVersion).contains(snapshot.schemaVersion) else {
            throw PersistenceError.unsupportedSchema(snapshot.schemaVersion)
        }
        if snapshot.schemaVersion < AppSnapshot.currentSchemaVersion {
            snapshot.schemaVersion = AppSnapshot.currentSchemaVersion
            snapshot.preferences.normalize()
            record.schemaVersion = AppSnapshot.currentSchemaVersion
            record.payload = try encoder.encode(snapshot)
            try context.save()
        }
        return snapshot
    }

    func save(_ snapshot: AppSnapshot) throws {
        let payload = try encoder.encode(snapshot)
        if let record = try records().first {
            record.schemaVersion = snapshot.schemaVersion
            record.payload = payload
        } else {
            context.insert(
                PersistentAppState(
                    schemaVersion: snapshot.schemaVersion,
                    payload: payload
                )
            )
        }
        try context.save()
    }

    func reset(to snapshot: AppSnapshot) throws {
        for record in try records() {
            context.delete(record)
        }
        context.insert(
            PersistentAppState(
                schemaVersion: snapshot.schemaVersion,
                payload: try encoder.encode(snapshot)
            )
        )
        try context.save()
    }

    func recordCount() throws -> Int {
        try records().count
    }

    private func records() throws -> [PersistentAppState] {
        var descriptor = FetchDescriptor<PersistentAppState>()
        descriptor.fetchLimit = 2
        return try context.fetch(descriptor)
    }
}

@MainActor
final class InMemoryAppStatePersistence: AppStatePersistence {
    private var snapshot: AppSnapshot?

    init(snapshot: AppSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() throws -> AppSnapshot? { snapshot }

    func save(_ snapshot: AppSnapshot) throws {
        self.snapshot = snapshot
    }

    func reset(to snapshot: AppSnapshot) throws {
        self.snapshot = snapshot
    }

    func recordCount() throws -> Int {
        snapshot == nil ? 0 : 1
    }
}

@MainActor
enum AppStatePersistenceFactory {
    static func makeDefault() -> any AppStatePersistence {
        do {
            return try SwiftDataAppStatePersistence()
        } catch {
            assertionFailure("SwiftData initialization failed: \(error)")
            return InMemoryAppStatePersistence()
        }
    }
}
