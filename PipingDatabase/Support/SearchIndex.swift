import Foundation

struct SearchEntry: Identifiable {
    let id = UUID()
    let moduleID: String
    let moduleName: String
    let title: String
    let subtitle: String
    let route: String
    let haystack: String   // lowercased searchable text
}

/// In-memory search index over every dataset. Tokenized matching: all query
/// tokens must appear somewhere in an entry's haystack ("2 300 wn" → the
/// 2" Class 300 weld-neck flange).
final class SearchIndex {
    static let shared = SearchIndex()
    private(set) lazy var entries: [SearchEntry] = Self.build()

    func search(_ query: String, limit: Int = 60) -> [SearchEntry] {
        let tokens = query.lowercased()
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "#", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        guard !tokens.isEmpty else { return [] }
        var out: [SearchEntry] = []
        for e in entries {
            if tokens.allSatisfy({ e.haystack.contains($0) }) {
                out.append(e)
                if out.count >= limit { break }
            }
        }
        return out
    }

    private static func build() -> [SearchEntry] {
        var out: [SearchEntry] = []
        let store = ReferenceStore.shared

        if let seed = try? Seeder.loadSeed() {
            for size in seed.sizes {
                for e in size.entries {
                    out.append(SearchEntry(
                        moduleID: "pipe", moduleName: "Pipe Schedule",
                        title: "\(size.nps)\" Sch \(e.s) Pipe",
                        subtitle: "OD \(fmt(size.od)) · wall \(fmt(e.w)) · \(e.std ?? "ASME B36.10M")",
                        route: "pipe|nps=\(size.nps)&s=\(e.s)",
                        haystack: "pipe \(size.nps) dn \(size.dn) sch schedule \(e.s) \(e.std ?? "") b36.10 b36.19".lowercased()))
                }
            }
        }

        let bwLabels = Dictionary(uniqueKeysWithValues: FittingsView.bwTypeLabels)
        for fitting in store.buttWeldFittings {
            let label = bwLabels[fitting.type] ?? fitting.type
            let sizeText = fitting.nps2.map { "\(fitting.nps) × \($0)" } ?? fitting.nps
            out.append(SearchEntry(
                moduleID: "fittings", moduleName: "Fittings",
                title: "\(sizeText)\" \(label)",
                subtitle: "Butt weld · ASME B16.9",
                route: "fittings|c=BW&t=\(fitting.type)&nps=\(fitting.nps)&nps2=\(fitting.nps2 ?? "")",
                haystack: "fitting bw butt weld \(label) \(fitting.type) \(sizeText) b16.9".lowercased()))
        }

        let forgedLabels = Dictionary(uniqueKeysWithValues: FittingsView.forgedTypeLabels)
        for fitting in store.forged?.fittings ?? [] {
            let label = forgedLabels[fitting.type] ?? fitting.type
            let conn = fitting.connection ?? "SW"
            let connName = conn == "SW" ? "socket weld" : "threaded"
            out.append(SearchEntry(
                moduleID: "fittings", moduleName: "Fittings",
                title: "\(fitting.nps)\" \(label) \(fitting.class ?? "")# \(conn)",
                subtitle: "\(connName.capitalized) · ASME B16.11",
                route: "fittings|c=\(conn)&t=\(fitting.type)&cl=\(fitting.class ?? "")&nps=\(fitting.nps)",
                haystack: "fitting forged \(conn) \(connName) \(label) \(fitting.type) \(fitting.class ?? "") \(fitting.nps) b16.11".lowercased()))
        }

        let flangeLabels = Dictionary(uniqueKeysWithValues: FlangesView.typeLabels)
        for cls in store.flanges?.classes ?? [] {
            for size in cls.sizes {
                for (short, long) in FlangesView.typeLabels {
                    guard size.weights?[short] != nil || size.perType?[short] != nil
                            || (short == "SO" && size.weights?["THSO"] != nil) else { continue }
                    out.append(SearchEntry(
                        moduleID: "flanges", moduleName: "Flanges",
                        title: "\(size.label)\" \(cls.class)# \(long) Flange",
                        subtitle: size.series ?? "ASME B16.5",
                        route: "flanges|cl=\(cls.class)&t=\(short)&k=\(size.key)",
                        haystack: "flange \(cls.class) \(long) \(short) \(size.label) \(size.series ?? "b16.5")".lowercased()))
                }
            }
        }
        _ = flangeLabels

        let valveNames = ["gate": "Gate", "globe": "Globe", "swingCheck": "Swing Check",
                          "ballFullReduced": "Ball", "ballFullBore": "Ball (Full Bore)"]
        // One entry per type/class/size (facings share a screen).
        var seenValves = Set<String>()
        for v in store.valves?.valves ?? [] {
            let key = "\(v.type)|\(v.class)|\(v.nps)"
            guard seenValves.insert(key).inserted else { continue }
            let name = valveNames[v.type] ?? v.type
            out.append(SearchEntry(
                moduleID: "valves", moduleName: "Valves",
                title: "\(v.nps)\" \(v.class)# \(name) Valve",
                subtitle: "Face-to-face / end-to-end · ASME B16.10",
                route: "valves|t=\(v.type)&cl=\(v.class)&f=\(v.facing)&nps=\(v.nps)",
                haystack: "valve \(name) \(v.type) \(v.class) \(v.nps) b16.10 check ball gate globe".lowercased()))
        }

        for o in store.olets?.olets ?? [] {
            out.append(SearchEntry(
                moduleID: "olets", moduleName: "Branch Connections",
                title: "\(o.branch)\" \(o.type.capitalized) \(o.class)",
                subtitle: "Run \(o.runRangeText) · MSS SP-97",
                route: "olets|t=\(o.type)&cl=\(o.class)&b=\(o.branch)",
                haystack: "olet branch \(o.type) \(o.class) \(o.branch) sp-97 sp97 weldolet sockolet thredolet".lowercased()))
        }

        for b in store.lineBlanks?.blanks ?? [] {
            out.append(SearchEntry(
                moduleID: "blanks", moduleName: "Line Blanks",
                title: "\(b.nps)\" \(b.class)# Spectacle Blind",
                subtitle: "OD \(fmt(b.odO)) · t \(fmt(b.thk)) · ASME B16.48",
                route: "blanks|cl=\(b.class)&nps=\(b.nps)",
                haystack: "blank blind spectacle figure-8 figure 8 spacer paddle \(b.class) \(b.nps) b16.48".lowercased()))
        }

        for g in store.gaskets?.gaskets ?? [] {
            out.append(SearchEntry(
                moduleID: "gaskets", moduleName: "Gaskets",
                title: "\(g.nps)\" \(g.class)# Gasket",
                subtitle: "Ring \(fmt(g.ringID)) × \(fmt(g.ringOD)) · ASME B16.21",
                route: "gaskets|cl=\(g.class)&nps=\(g.nps)",
                haystack: "gasket ring full face \(g.class) \(g.nps) b16.21".lowercased()))
        }

        return out
    }

    private static func fmt(_ v: Double) -> String { String(format: "%.3f", v) }
}
