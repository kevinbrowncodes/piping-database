import Foundation
import Observation

// Reference datasets beyond pipe schedule are read-only lookup tables with
// heterogeneous shapes; they load once from bundled JSON into value types.
// SwiftData remains the store for pipe schedule (@Query-driven) and for
// user data (favorites, recents) where persistence actually matters.

struct FittingsFile: Decodable {
    let version: Int
    let source: String
    let standard: String
    let legend: [String: String]
    let fittings: [Fitting]

    struct Fitting: Decodable, Identifiable {
        let type: String
        let connection: String?   // forged fittings: "SW"/"TH"; nil = butt-weld
        let `class`: String?      // forged fittings: "3000"/"6000"/"9000"
        let nps: String
        let nps2: String?
        let dims: [String: Double]
        let weights: [String: Double]?
        let weight: Double?

        var id: String {
            [type, connection ?? "", `class` ?? "", nps, nps2 ?? ""].joined(separator: "|")
        }
    }
}

struct FlangesFile: Decodable {
    let version: Int
    let source: String
    let standard: String
    let legend: [String: String]
    let classes: [FlangeClass]

    struct FlangeClass: Decodable {
        let `class`: String
        let sizes: [FlangeSize]
    }
    struct FlangeSize: Decodable {
        let nps: String
        let dims: [String: Double]
        let perType: [String: [String: Double]]?
        let drilling: Drilling
        let weights: [String: Double]?
    }
    struct Drilling: Decodable {
        let boltCircle: Double
        let numHoles: Int
        let holeDia: Double
        let boltDia: String
    }
}

struct OletsFile: Decodable {
    let version: Int
    let source: String
    let standard: String
    let legend: [String: String]
    let olets: [Olet]

    struct Olet: Decodable, Identifiable {
        let type: String
        let `class`: String
        let branch: String
        let runFrom: String
        let runTo: String
        let dims: [String: Double]
        let weight: Double?

        var id: String { [type, `class`, branch, runFrom, runTo].joined(separator: "|") }
    }
}

struct ValvesFile: Decodable {
    let version: Int
    let source: String
    let standard: String
    let valves: [Valve]

    struct Valve: Decodable {
        let type: String
        let `class`: String
        let facing: String
        let nps: String
        let inches: Double
    }
}

struct LineBlanksFile: Decodable {
    let version: Int
    let source: String
    let standard: String
    let blanks: [Blank]

    struct Blank: Decodable {
        let `class`: String
        let nps: String
        let idB: Double
        let odO: Double
        let thk: Double
        let blindWeight: Double?
        let spacerWeight: Double?
    }
}

/// Loads the bundled datasets once; immutable thereafter.
final class ReferenceStore {
    static let shared = ReferenceStore()

    private static func load<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    let elbows: FittingsFile? = load("FittingsElbows")
    let tees: FittingsFile? = load("FittingsTees")
    let reducersCapsStubs: FittingsFile? = load("FittingsReducersCapsStubs")
    let forged: FittingsFile? = load("FittingsForged")
    let flanges: FlangesFile? = load("Flanges")
    let olets: OletsFile? = load("Olets")
    let valves: ValvesFile? = load("Valves")
    let lineBlanks: LineBlanksFile? = load("LineBlanks")

    /// All butt-weld fittings across the three Weldbend files.
    var buttWeldFittings: [FittingsFile.Fitting] {
        [elbows, tees, reducersCapsStubs].compactMap { $0 }.flatMap(\.fittings)
    }

    var buttWeldLegend: [String: String] {
        [elbows, tees, reducersCapsStubs].compactMap { $0 }
            .reduce(into: [:]) { $0.merge($1.legend) { a, _ in a } }
    }
}

/// Sorting helper for NPS strings like "1/2", "1 1/4", "26".
enum NPS {
    static func value(_ s: String) -> Double {
        let parts = s.split(separator: " ")
        var total = 0.0
        for p in parts {
            if p.contains("/") {
                let f = p.split(separator: "/")
                if f.count == 2, let n = Double(f[0]), let d = Double(f[1]), d != 0 {
                    total += n / d
                }
            } else {
                total += Double(p) ?? 0
            }
        }
        return total
    }

    static func sorted(_ list: some Sequence<String>) -> [String] {
        Array(Set(list)).sorted { value($0) < value($1) }
    }
}
