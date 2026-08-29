import Foundation
import SwiftData

/// User data: a starred or recently-viewed selection in any module.
/// Lives outside the reference-data models so seed migrations never touch it.
@Model
final class SavedLookup {
    var moduleID: String     // "pipe", "fittings", ...
    var payload: String      // selection state, e.g. "nps=1/2&s=40"
    var title: String        // "1/2\" Sch 40 Pipe"
    var detail: String       // "OD 0.840 · Wall 0.109"
    var isFavorite: Bool
    var lastUsed: Date

    init(moduleID: String, payload: String, title: String, detail: String,
         isFavorite: Bool = false, lastUsed: Date = .now) {
        self.moduleID = moduleID
        self.payload = payload
        self.title = title
        self.detail = detail
        self.isFavorite = isFavorite
        self.lastUsed = lastUsed
    }

    /// Route string consumed by ModuleListView's navigationDestination.
    var route: String { payload.isEmpty ? moduleID : "\(moduleID)|\(payload)" }
}

enum LookupStore {
    static let recentsCap = 30

    static func find(_ ctx: ModelContext, moduleID: String, payload: String, favorite: Bool) -> SavedLookup? {
        var d = FetchDescriptor<SavedLookup>(predicate: #Predicate {
            $0.moduleID == moduleID && $0.payload == payload && $0.isFavorite == favorite
        })
        d.fetchLimit = 1
        return (try? ctx.fetch(d))?.first
    }

    static func isFavorite(_ ctx: ModelContext, moduleID: String, payload: String) -> Bool {
        find(ctx, moduleID: moduleID, payload: payload, favorite: true) != nil
    }

    static func toggleFavorite(_ ctx: ModelContext, moduleID: String, payload: String,
                               title: String, detail: String) {
        if let existing = find(ctx, moduleID: moduleID, payload: payload, favorite: true) {
            ctx.delete(existing)
        } else {
            ctx.insert(SavedLookup(moduleID: moduleID, payload: payload,
                                   title: title, detail: detail, isFavorite: true))
        }
        try? ctx.save()
    }

    static func recordRecent(_ ctx: ModelContext, moduleID: String, payload: String,
                             title: String, detail: String) {
        if let existing = find(ctx, moduleID: moduleID, payload: payload, favorite: false) {
            existing.lastUsed = .now
            existing.title = title
            existing.detail = detail
        } else {
            ctx.insert(SavedLookup(moduleID: moduleID, payload: payload, title: title, detail: detail))
        }
        // Trim oldest recents beyond the cap.
        let all = (try? ctx.fetch(FetchDescriptor<SavedLookup>(
            predicate: #Predicate { !$0.isFavorite },
            sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
        ))) ?? []
        for stale in all.dropFirst(recentsCap) { ctx.delete(stale) }
        try? ctx.save()
    }
}
