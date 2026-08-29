import Foundation
import SwiftData

/// One nominal pipe size (NPS/DN). OD is fixed per NPS for steel pipe,
/// so it lives here rather than on each schedule entry.
@Model
final class NominalSize {
    var nps: String          // "1/2", "1 1/4", "12"
    var sortValue: Double    // numeric NPS for ordering (0.5, 1.25, 12)
    var dn: Int              // DN equivalent (15, 32, 300)
    var odInches: Double     // outside diameter, ASME B36.10M/B36.19M

    @Relationship(deleteRule: .cascade, inverse: \PipeScheduleEntry.size)
    var entries: [PipeScheduleEntry]

    init(nps: String, sortValue: Double, dn: Int, odInches: Double, entries: [PipeScheduleEntry] = []) {
        self.nps = nps
        self.sortValue = sortValue
        self.dn = dn
        self.odInches = odInches
        self.entries = entries
    }
}
