import Foundation

struct SearchEntry: Identifiable {
    let id = UUID()
    let moduleID: String
    let moduleName: String
    let title: String
    let subtitle: String
    let route: String
    let haystack: String   // lowercased searchable text
    let size: String       // primary NPS ("6", "1/8", "2 1/2") for ranking
    let tokens: Set<String>

    init(moduleID: String, moduleName: String, title: String, subtitle: String,
         route: String, haystack: String, size: String = "") {
        self.moduleID = moduleID
        self.moduleName = moduleName
        self.title = title
        self.subtitle = subtitle
        self.route = route
        self.haystack = haystack
        self.size = size.lowercased()
        self.tokens = Set(SearchIndex.tokenize(haystack))
    }
}

/// In-memory search index over every dataset. Tokenized matching: every
/// query token must be found in the entry ("2 300 wn" → the 2" Class 300
/// weld-neck flange). Numbers match whole tokens only, so "2" is not 12",
/// 1/2" or 2 1/2", and "6" is not B36.10 (BUG-0006); words match anywhere.
final class SearchIndex {
    static let shared = SearchIndex()
    private(set) lazy var entries: [SearchEntry] = Self.build()

    /// Splits on spaces/commas and keeps trade mixed numbers together, so
    /// "2 1/2" is one token and never also a bare "2".
    static func tokenize(_ text: String) -> [String] {
        let raw = text.lowercased()
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "#", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        var out: [String] = []
        var i = 0
        while i < raw.count {
            if i + 1 < raw.count, isWhole(raw[i]), isFraction(raw[i + 1]) {
                out.append(raw[i] + " " + raw[i + 1]); i += 2
            } else {
                out.append(raw[i]); i += 1
            }
        }
        return out
    }

    private static func isWhole(_ t: String) -> Bool { !t.isEmpty && t.allSatisfy(\.isNumber) }
    private static func isFraction(_ t: String) -> Bool {
        t.range(of: #"^[0-9]+/[0-9]+$"#, options: .regularExpression) != nil
    }

    /// "2", "300", "1/2", "2 1/2", "0.5" — a size, class or schedule number.
    static func isNumeric(_ token: String) -> Bool {
        token.range(of: #"^[0-9]+( [0-9]+/[0-9]+|/[0-9]+|\.[0-9]+)?$"#, options: .regularExpression) != nil
    }

    static func matches(_ e: SearchEntry, tokens: [String]) -> Bool {
        tokens.allSatisfy { isNumeric($0) ? e.tokens.contains($0) : e.haystack.contains($0) }
    }

    /// Rows whose own size is one of the query numbers come first: "sch 80 6"
    /// is the 6" pipe before the 1/8" pipe that merely happens to be DN 6.
    func search(_ query: String, limit: Int = 60) -> [SearchEntry] {
        let tokens = Self.tokenize(query)
        guard !tokens.isEmpty else { return [] }
        let numbers = Set(tokens.filter(Self.isNumeric))
        var hits: [(SearchEntry, Int)] = []
        for e in entries where Self.matches(e, tokens: tokens) {
            hits.append((e, numbers.contains(e.size) ? 1 : 0))
            if hits.count >= limit * 4 { break }
        }
        let ranked = hits.enumerated().sorted { a, b in
            a.element.1 != b.element.1 ? a.element.1 > b.element.1 : a.offset < b.offset
        }
        return ranked.prefix(limit).map(\.element.0)
    }

    private static func build() -> [SearchEntry] {
        var out: [SearchEntry] = []
        let store = ReferenceStore.shared

        if let seed = try? Seeder.loadSeed() {
            for size in seed.sizes {
                for e in size.entries {
                    // "80S" is the stainless 80: index the bare number too so
                    // "sch 80" finds both.
                    let schedNumber = e.s.hasSuffix("S") ? String(e.s.dropLast()) : ""
                    out.append(SearchEntry(
                        moduleID: "pipe", moduleName: "Pipe Schedule",
                        title: "\(size.nps)\" Sch \(e.s) Pipe",
                        subtitle: "OD \(fmt(size.od)) · wall \(fmt(e.w)) · \(e.std ?? "ASME B36.10M")",
                        route: "pipe|nps=\(size.nps)&s=\(e.s)",
                        haystack: "pipe \(size.nps) dn \(size.dn) sch schedule \(e.s) \(schedNumber) \(e.std ?? "") b36.10 b36.19".lowercased(),
                        size: size.nps))
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
                haystack: "fitting bw butt weld \(label) \(fitting.type) \(sizeText) b16.9".lowercased(),
                size: fitting.nps))
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
                haystack: "fitting forged \(conn) \(connName) \(label) \(fitting.type) \(fitting.class ?? "") \(fitting.nps) b16.11".lowercased(),
                size: fitting.nps))
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
                        haystack: "flange \(cls.class) \(long) \(short) \(size.label) \(size.series ?? "b16.5")".lowercased(),
                        size: size.nps))
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
                haystack: "valve \(name) \(v.type) \(v.class) \(v.nps) b16.10 check ball gate globe".lowercased(),
                size: v.nps))
        }

        for o in store.olets?.olets ?? [] {
            out.append(SearchEntry(
                moduleID: "olets", moduleName: "Branch Connections",
                title: "\(o.branch)\" \(o.type.capitalized) \(o.class)",
                subtitle: "\(o.runSummary) · MSS SP-97",
                route: "olets|t=\(o.type)&cl=\(o.class)&b=\(o.branch)",
                haystack: "olet branch \(o.type) \(o.class) \(o.branch) sp-97 sp97 weldolet sockolet thredolet".lowercased(),
                size: o.branch))
        }

        for b in store.lineBlanks?.blanks ?? [] {
            out.append(SearchEntry(
                moduleID: "blanks", moduleName: "Line Blanks",
                title: "\(b.nps)\" \(b.class)# Spectacle Blind",
                subtitle: "OD \(fmt(b.odO)) · t \(fmt(b.thk)) · ASME B16.48",
                route: "blanks|cl=\(b.class)&nps=\(b.nps)",
                haystack: "blank blind spectacle figure-8 figure 8 spacer paddle \(b.class) \(b.nps) b16.48".lowercased(),
                size: b.nps))
        }

        for g in store.gaskets?.gaskets ?? [] {
            out.append(SearchEntry(
                moduleID: "gaskets", moduleName: "Gaskets",
                title: "\(g.nps)\" \(g.class)# Gasket",
                subtitle: "Ring \(fmt(g.ringID)) × \(fmt(g.ringOD)) · ASME B16.21",
                route: "gaskets|cl=\(g.class)&nps=\(g.nps)",
                haystack: "gasket ring full face \(g.class) \(g.nps) b16.21".lowercased(),
                size: g.nps))
        }

        return out
    }

    private static func fmt(_ v: Double) -> String { String(format: "%.3f", v) }
}
