import Foundation
import SwiftData

enum Seeder {
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
        let std: String?     // defaults to B36.10M
    }

    static func seedIfNeeded(container: ModelContainer) throws {
        let context = ModelContext(container)
        let existing = try context.fetchCount(FetchDescriptor<NominalSize>())
        guard existing == 0 else { return }

        guard let url = Bundle.main.url(forResource: "PipeSeed", withExtension: "json") else {
            assertionFailure("PipeSeed.json missing from bundle")
            return
        }
        let seed = try JSONDecoder().decode(SeedFile.self, from: Data(contentsOf: url))

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
    }
}
