import SwiftUI
import SwiftData

@main
struct PipingDatabaseApp: App {
    let container: ModelContainer

    init() {
        #if DEBUG
        // UI-test/automation hook (never compiled into Release): reset
        // preferences for deterministic runs. Explicit key list, not
        // removePersistentDomain — Seeder.versionKey must survive or every
        // test launch pays a full re-seed.
        let uitestReset = ProcessInfo.processInfo.environment["UITEST_RESET"] == "1"
        if uitestReset {
            for key in PrefKey.all { UserDefaults.standard.removeObject(forKey: key) }
        }
        #endif
        do {
            container = try ModelContainer(for: NominalSize.self, PipeScheduleEntry.self, SavedLookup.self)
            #if DEBUG
            if uitestReset {
                // Determinism covers user data too: favorites/recents change
                // the module list's sections.
                let context = ModelContext(container)
                try? context.delete(model: SavedLookup.self)
                try? context.save()
            }
            #endif
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
    @State private var selectedTab: String = {
        #if DEBUG
        if let tab = ProcessInfo.processInfo.environment["OPEN_TAB"],
           ["modules", "calculator", "settings"].contains(tab) {
            return tab
        }
        #endif
        return "modules"
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Modules", systemImage: "square.grid.2x2", value: "modules") {
                ModuleListView()
            }
            Tab("Calculator", systemImage: "plus.forwardslash.minus", value: "calculator") {
                NavigationStack { TradeCalcView() }
            }
            Tab("Settings", systemImage: "gearshape", value: "settings") {
                NavigationStack { SettingsView() }
            }
        }
    }
}
