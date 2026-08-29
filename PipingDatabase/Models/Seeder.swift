import Foundation
import SwiftData

enum Seeder {
    static let versionKey = "pipeSeedVersion"

    struct SeedFile: Decodable {
        let version: Int
        let sizes: [SeedSize]
    }
    struct SeedSize: Decodable {
        let nps: String
        let sort: Double
        let dn: Int
        let od: Double
        let entries: [SeedEntry]
    }
    struct SeedEntry: Decodable {
        let s: String        // schedule designation
        let w: Double        // wall, inches
        let std: String?     // source standard, defaults to B36.10M
    }

    /// Seeds reference data on first launch, and re-seeds when the bundled
    /// seed version changes. Reference data is disposable by design — user
    /// data (favorites etc.) lives in separate models and is never touched.
    static func seedIfNeeded(container: ModelContainer, defaults: UserDefaults = .standard) throws {
        let context = ModelContext(container)
        let seed = try loadSeed()
        let existing = try context.fetchCount(FetchDescriptor<NominalSize>())
        let storedVersion = defaults.integer(forKey: versionKey)
        guard existing == 0 || storedVersion != seed.version else { return }

        try context.delete(model: NominalSize.self)   // cascades to entries

        for s in seed.sizes {
            let size = NominalSize(nps: s.nps, sortValue: s.sort, dn: s.dn, odInches: s.od)
            context.insert(size)
            for e in s.entries {
                let entry = PipeScheduleEntry(
                    designation: e.s,
                    wallInches: e.w,
                    standard: e.std ?? "ASME B36.10M"
                )
                entry.size = size
                context.insert(entry)
            }
        }
        try context.save()
        defaults.set(seed.version, forKey: versionKey)
    }

    static func loadSeed() throws -> SeedFile {
        guard let url = Bundle.main.url(forResource: "PipeSeed", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(SeedFile.self, from: Data(contentsOf: url))
    }
}
