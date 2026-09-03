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
        let series: String?      // "B16.47 Series A"/"B" for NPS ≥ 30
        let dims: [String: Double]
        let perType: [String: [String: Double]]?
        let drilling: Drilling
        let weights: [String: Double]?

        var key: String { series.map { "\(nps)|\($0)" } ?? nps }

        /// Standard this row conforms to: B16.47 series for NPS ≥ 30,
        /// B16.1 for Class 125 cast-iron drilling, otherwise B16.5 (BUG-0008).
        func sourceLabel(class cls: String) -> String {
            if let series { return series }
            return cls == "125" ? "ASME B16.1" : "ASME B16.5"
        }
        var label: String {
            guard let series else { return nps }
            return "\(nps) \(series.hasSuffix("A") ? "A" : "B")"
        }
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
        let runFrom: String?    // absent = "order to specific run size"
        let runTo: String?
        let dims: [String: Double]
        let weight: Double?

        var id: String {
            [type, `class`, branch, runFrom ?? "", runTo ?? ""].joined(separator: "|")
        }

        var runRangeText: String {
            guard let from = runFrom, let to = runTo else { return "Order to run size" }
            return from == to ? "\(from)\" (size on size)" : "\(from)\" – \(to)\""
        }

        /// One-line summary for lists: "Run 3/4" – 36"" or "Order to run size".
        var runSummary: String {
            runFrom == nil ? runRangeText : "Run \(runRangeText)"
        }
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

struct GasketsFile: Decodable {
    let version: Int
    let source: String
    let standard: String
    let gaskets: [Gasket]

    struct Gasket: Decodable {
        let `class`: String
        let nps: String
        let ringID: Double
        let ringOD: Double
        let ffOD: Double?
        let ffHoles: Int?
        let ffHoleDia: Double?
        let ffBoltCircle: Double?
    }
}

struct PTRatingsFile: Decodable {
    let version: Int
    let source: String
    let standard: String
    let materialGroup: String
    let materials: String
    let temperaturesF: [Int]
    let note: String
    let classes: [String: [Int]]

    func rating(class cls: String, tempF: Int) -> Int? {
        guard let idx = temperaturesF.firstIndex(of: tempF) else { return nil }
        return classes[cls]?[idx]
    }
}

struct BoltTorqueFile: Decodable {
    let version: Int
    let source: String
    let note: String
    let stressesPsi: [Int]
    let boltDiameters: [String]
    let torqueFtLbs: [String: [Int]]
    let procedure: [String]

    func torque(boltDia: String, stressPsi: Int) -> Int? {
        guard let col = boltDiameters.firstIndex(of: boltDia) else { return nil }
        return torqueFtLbs[String(stressPsi)]?[col]
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
    let ptRatings: PTRatingsFile? = load("PTRatings")
    let boltTorque: BoltTorqueFile? = load("BoltTorque")
    let gaskets: GasketsFile? = load("Gaskets")

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
