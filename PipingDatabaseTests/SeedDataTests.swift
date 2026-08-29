import Testing
import Foundation
@testable import PipingDatabase

/// Layer 1 of docs/TESTING.md: the bundled seed is validated structurally,
/// against physical invariants, and against golden values transcribed from
/// sources INDEPENDENT of the ones the generator script used.
struct SeedDataTests {
    static let seed: Seeder.SeedFile = {
        // TEST_HOST makes Bundle.main the app bundle.
        try! Seeder.loadSeed()
    }()

    // MARK: Structure

    @Test func versionAndCounts() {
        #expect(Self.seed.version == 2)
        #expect(Self.seed.sizes.count == 32)
        #expect(Self.seed.sizes.flatMap(\.entries).count == 367)
    }

    @Test func noDuplicates() {
        let npses = Self.seed.sizes.map(\.nps)
        #expect(Set(npses).count == npses.count)
        for size in Self.seed.sizes {
            let designations = size.entries.map(\.s)
            #expect(Set(designations).count == designations.count, "duplicate schedule in \(size.nps)")
        }
    }

    @Test func everyEntryHasKnownStandard() {
        for entry in Self.seed.sizes.flatMap(\.entries) {
            let std = entry.std ?? "ASME B36.10M"
            #expect(std == "ASME B36.10M" || std == "ASME B36.19M")
            if entry.s.hasSuffix("S") && entry.s != "XS" && entry.s != "XXS" {
                #expect(std == "ASME B36.19M", "stainless designation \(entry.s) mislabeled")
            }
        }
    }

    // MARK: Physical invariants

    @Test func outsideDiametersIncrease() {
        let sorted = Self.seed.sizes.sorted { $0.sort < $1.sort }
        for (a, b) in zip(sorted, sorted.dropFirst()) {
            #expect(a.od < b.od, "\(a.nps) → \(b.nps)")
        }
    }

    @Test func wallsWithinPhysicalBounds() {
        for size in Self.seed.sizes {
            for entry in size.entries {
                #expect(entry.w > 0 && entry.w < size.od / 2, "\(size.nps) Sch \(entry.s)")
            }
        }
    }

    @Test func stdMatchesSch40UpTo10AndXsMatchesSch80UpTo8() {
        for size in Self.seed.sizes {
            let walls = Dictionary(uniqueKeysWithValues: size.entries.map { ($0.s, $0.w) })
            if size.sort <= 10, let std = walls["STD"], let s40 = walls["40"] {
                #expect(std == s40, "\(size.nps)")
            }
            if size.sort <= 8, let xs = walls["XS"], let s80 = walls["80"] {
                #expect(xs == s80, "\(size.nps)")
            }
        }
    }

    @Test func largeBoreODEqualsNPS() {
        for size in Self.seed.sizes where size.sort >= 14 {
            #expect(size.od == size.sort, "\(size.nps)")
        }
    }

    @Test func numberedSchedulesMonotonic() {
        let order = ["5", "10", "20", "30", "40", "60", "80", "100", "120", "140", "160"]
        for size in Self.seed.sizes {
            let walls = Dictionary(uniqueKeysWithValues: size.entries.map { ($0.s, $0.w) })
            let seq = order.compactMap { walls[$0] }
            #expect(seq == seq.sorted(), "non-monotonic schedules in \(size.nps)")
        }
    }

    // MARK: Golden values (independent sources)

    /// Transcribed from flangeboltchart.com, the Octal Steel metric chart
    /// (converted mm → in), and the reference app's screens — NOT from the
    /// Weldbend pages the generator was built from.
    static let goldenWalls: [String: Double] = [
        "1/8|10": 0.049, "1/4|30": 0.073, "3/8|STD": 0.091,
        "1/2|40": 0.109, "1/2|160": 0.188, "1/2|XXS": 0.294, "1/2|5S": 0.065,
        "3/4|XXS": 0.308, "1|5": 0.065, "2|XS": 0.218, "2|40S": 0.154,
        "3|160": 0.438, "4|120": 0.438, "5|XXS": 0.750, "6|80": 0.432,
        "8|60": 0.406, "8|XXS": 0.875, "8|5S": 0.109,
        "10|80": 0.594, "10|40S": 0.365, "12|40": 0.406, "12|STD": 0.375,
        "12|40S": 0.375, "12|80S": 0.500, "14|10": 0.250, "14|10S": 0.188,
        "16|40": 0.500, "18|30": 0.438, "20|40": 0.594, "22|60": 0.875,
        "24|160": 2.344, "24|10S": 0.250, "26|10": 0.312, "30|5": 0.250,
        "34|10": 0.312, "36|40": 0.750, "42|XS": 0.500, "48|STD": 0.375,
    ]

    @Test func goldenWallThicknesses() {
        for (key, expected) in Self.goldenWalls {
            let parts = key.split(separator: "|")
            let size = Self.seed.sizes.first { $0.nps == parts[0] }
            #expect(size != nil, "missing size \(parts[0])")
            let entry = size?.entries.first { $0.s == parts[1] }
            #expect(entry?.w == expected, "\(key): got \(entry?.w ?? -1), want \(expected)")
        }
    }

    static let goldenODs: [String: Double] = [
        "1/8": 0.405, "1/2": 0.840, "2": 2.375, "6": 6.625,
        "10": 10.750, "12": 12.750, "14": 14.000, "48": 48.000,
    ]

    @Test func goldenOutsideDiameters() {
        for (nps, od) in Self.goldenODs {
            #expect(Self.seed.sizes.first { $0.nps == nps }?.od == od, "\(nps)")
        }
    }

    @Test func goldenDNMapping() {
        let dns: [String: Int] = ["1/2": 15, "2": 50, "12": 300, "24": 600, "36": 900]
        for (nps, dn) in dns {
            #expect(Self.seed.sizes.first { $0.nps == nps }?.dn == dn, "\(nps)")
        }
    }
}
