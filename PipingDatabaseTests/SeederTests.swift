import Testing
import Foundation
import SwiftData
@testable import PipingDatabase

/// Layer 3 of docs/TESTING.md: seeding behavior against in-memory stores.
@MainActor
struct SeederTests {
    private func freshContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: NominalSize.self, PipeScheduleEntry.self, configurations: config)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "SeederTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func seedsOnceAndIsIdempotent() throws {
        let container = try freshContainer()
        let defaults = freshDefaults()
        try Seeder.seedIfNeeded(container: container, defaults: defaults)
        let context = ModelContext(container)
        let sizes = try context.fetchCount(FetchDescriptor<NominalSize>())
        let entries = try context.fetchCount(FetchDescriptor<PipeScheduleEntry>())
        #expect(sizes == 32)
        #expect(entries == 367)

        try Seeder.seedIfNeeded(container: container, defaults: defaults)
        #expect(try context.fetchCount(FetchDescriptor<NominalSize>()) == sizes)
        #expect(try context.fetchCount(FetchDescriptor<PipeScheduleEntry>()) == entries)
    }

    @Test func versionBumpReplacesInsteadOfDuplicating() throws {
        let container = try freshContainer()
        let defaults = freshDefaults()
        try Seeder.seedIfNeeded(container: container, defaults: defaults)
        defaults.set(1, forKey: Seeder.versionKey) // simulate stale seed
        try Seeder.seedIfNeeded(container: container, defaults: defaults)
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<NominalSize>()) == 32)
        #expect(try context.fetchCount(FetchDescriptor<PipeScheduleEntry>()) == 367)
        #expect(defaults.integer(forKey: Seeder.versionKey) == 2)
    }

    @Test func everyEntryLinksToASize() throws {
        let container = try freshContainer()
        try Seeder.seedIfNeeded(container: container, defaults: freshDefaults())
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<PipeScheduleEntry>())
        #expect(entries.allSatisfy { $0.size != nil })
    }
}
