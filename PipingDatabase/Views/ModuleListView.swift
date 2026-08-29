import SwiftUI

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
               symbol: "point.topleft.down.curvedto.point.bottomright.up", available: false),
        Module(id: "flanges", title: "Flanges",
               subtitle: "B16.5 · B16.47 — dimensions, drilling, bolting",
               symbol: "circle.hexagongrid", available: false),
        Module(id: "valves", title: "Valves",
               subtitle: "B16.10 — face-to-face, end-to-end",
               symbol: "triangle.lefthalf.filled", available: false),
        Module(id: "olets", title: "Branch Connections",
               subtitle: "MSS SP-97 — weldolet, sockolet, thredolet",
               symbol: "arrow.triangle.branch", available: false),
        Module(id: "blanks", title: "Line Blanks",
               subtitle: "B16.48 — figure-8, paddle blank, spacer",
               symbol: "8.circle", available: false),
        Module(id: "gaskets", title: "Gaskets",
               subtitle: "B16.21 — flat ring, full face, drilling",
               symbol: "circle.dashed", available: false),
    ]

    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(modules) { module in
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
            .navigationTitle("Piping Database")
            .navigationDestination(for: String.self) { id in
                switch id {
                case "pipe": PipeScheduleView()
                default: EmptyView()
                }
            }
            .onAppear {
                // Dev/automation hook: SIMCTL_CHILD_OPEN_MODULE=pipe deep-links on launch.
                if let target = ProcessInfo.processInfo.environment["OPEN_MODULE"], path.isEmpty {
                    path = [target]
                }
            }
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
