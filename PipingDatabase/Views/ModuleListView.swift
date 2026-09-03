import SwiftUI
import SwiftData

struct Module: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let available: Bool
}

struct ModuleListView: View {
    private let modules: [Module] = [
        Module(id: "pipe", title: "Pipe Schedule",
               subtitle: "B36.10M · B36.19M — dimensions, weights, volume",
               symbol: "circle.circle", available: true),
        Module(id: "fittings", title: "Fittings",
               subtitle: "B16.9 · B16.11 — elbows, tees, reducers, caps",
               symbol: "point.topleft.down.curvedto.point.bottomright.up", available: true),
        Module(id: "flanges", title: "Flanges",
               subtitle: "B16.5 · B16.47 — dimensions, drilling, bolting",
               symbol: "circle.hexagongrid", available: true),
        Module(id: "valves", title: "Valves",
               subtitle: "B16.10 — face-to-face, end-to-end",
               symbol: "triangle.lefthalf.filled", available: true),
        Module(id: "olets", title: "Branch Connections",
               subtitle: "MSS SP-97 — weldolet, sockolet, thredolet",
               symbol: "arrow.triangle.branch", available: true),
        Module(id: "blanks", title: "Line Blanks",
               subtitle: "B16.48 — figure-8, paddle blank, spacer",
               symbol: "8.circle", available: true),
        Module(id: "gaskets", title: "Gaskets",
               subtitle: "B16.21 — flat ring, full face, drilling",
               symbol: "circle.dashed", available: true),
    ]

    @State private var path: [String] = []
    @State private var searchText = ""
    @State private var didConsumeDeepLink = false
    @AppStorage(PrefKey.moduleOrder) private var moduleOrderRaw = ""
    @Environment(\.modelContext) private var context

    private var searchResults: [SearchEntry] {
        searchText.count >= 2 ? SearchIndex.shared.search(searchText) : []
    }

    @Query(filter: #Predicate<SavedLookup> { $0.isFavorite },
           sort: \SavedLookup.title) private var favorites: [SavedLookup]
    @Query(filter: #Predicate<SavedLookup> { !$0.isFavorite },
           sort: \SavedLookup.lastUsed, order: .reverse) private var recents: [SavedLookup]

    private var orderedModules: [Module] {
        let order = moduleOrderRaw.split(separator: ",").map(String.init)
        guard !order.isEmpty else { return modules }
        // Stable for ids missing from a stale saved order: fall back to
        // canonical position rather than letting them tie at .max.
        let canonical = Dictionary(uniqueKeysWithValues: modules.enumerated().map { ($1.id, $0) })
        return modules.sorted {
            (order.firstIndex(of: $0.id) ?? .max, canonical[$0.id] ?? 0)
                < (order.firstIndex(of: $1.id) ?? .max, canonical[$1.id] ?? 0)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // Search runs from two characters; a single character must not
                // claim "No Results" over the module list (BUG-0006).
                if searchText.count >= 2 {
                    if searchResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(searchResults) { result in
                            NavigationLink(value: result.route) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(result.title).font(.subheadline).bold()
                                    Text("\(result.moduleName) · \(result.subtitle)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                if !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(favorites) { fav in
                            savedRow(fav, symbol: "star.fill", tint: .yellow)
                        }
                        .onDelete { offsets in
                            offsets.map { favorites[$0] }.forEach(context.delete)
                            try? context.save()
                        }
                    }
                }

                Section {
                    ForEach(orderedModules) { module in
                        if module.available {
                            NavigationLink(value: module.id) {
                                ModuleRow(module: module)
                            }
                        } else {
                            ModuleRow(module: module)
                                .foregroundStyle(.secondary)
                                .badge(Text("Soon").font(.caption2))
                        }
                    }
                    .onMove { source, destination in
                        var ids = orderedModules.map(\.id)
                        ids.move(fromOffsets: source, toOffset: destination)
                        moduleOrderRaw = ids.joined(separator: ",")
                    }
                } header: {
                    if !favorites.isEmpty || !recents.isEmpty { Text("Modules") }
                }

                if !recents.isEmpty {
                    Section("Recent") {
                        ForEach(recents.prefix(8)) { recent in
                            savedRow(recent, symbol: "clock", tint: .secondary)
                        }
                        .onDelete { offsets in
                            offsets.map { Array(recents.prefix(8))[$0] }.forEach(context.delete)
                            try? context.save()
                        }
                    }
                }
                }
            }
            .searchable(text: $searchText, prompt: "2 300 wn · sch 80 6 · gate 600")
            .toolbar { EditButton() }
            .navigationTitle("PipeBase")
            .navigationDestination(for: String.self) { route in
                let parts = route.split(separator: "|", maxSplits: 1)
                let id = String(parts.first ?? "")
                let preselect = Self.parsePayload(parts.count > 1 ? String(parts[1]) : "")
                switch id {
                case "pipe": PipeScheduleView(preselect: preselect)
                case "fittings": FittingsView(preselect: preselect)
                case "flanges": FlangesView(preselect: preselect)
                case "valves": ValvesView(preselect: preselect)
                case "olets": OletsView(preselect: preselect)
                case "blanks": LineBlanksView(preselect: preselect)
                case "gaskets": GasketsView(preselect: preselect)
                default: EmptyView()
                }
            }
            .onAppear {
                #if DEBUG
                // Dev/automation hook (debug builds only), consumed once so
                // navigating back to the root works normally afterwards.
                if !didConsumeDeepLink, path.isEmpty,
                   let target = ProcessInfo.processInfo.environment["OPEN_MODULE"],
                   let head = target.split(separator: "|").first,
                   modules.contains(where: { $0.id == String(head) }) {
                    didConsumeDeepLink = true
                    path = [target]
                }
                #endif
            }
        }
    }

    private func savedRow(_ item: SavedLookup, symbol: String, tint: Color) -> some View {
        NavigationLink(value: item.route) {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(tint).frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(.subheadline).bold()
                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    static func parsePayload(_ payload: String) -> [String: String] {
        payload.split(separator: "&").reduce(into: [:]) { dict, pair in
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { dict[String(kv[0])] = String(kv[1]) }
        }
    }
}

private struct ModuleRow: View {
    let module: Module

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: module.symbol)
                .font(.title2)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(module.title).font(.headline)
                Text(module.subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
