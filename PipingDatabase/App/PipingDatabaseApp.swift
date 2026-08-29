import SwiftUI
import SwiftData

@main
struct PipingDatabaseApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: NominalSize.self, PipeScheduleEntry.self)
            try Seeder.seedIfNeeded(container: container)
        } catch {
            fatalError("Failed to set up model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Modules", systemImage: "square.grid.2x2") {
                ModuleListView()
            }
            Tab("Calculator", systemImage: "plus.forwardslash.minus") {
                NavigationStack { TradeCalcView() }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack { SettingsView() }
            }
        }
    }
}
