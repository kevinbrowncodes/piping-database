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
            ModuleListView()
        }
        .modelContainer(container)
    }
}
