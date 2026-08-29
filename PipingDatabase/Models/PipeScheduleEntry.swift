import Foundation
import SwiftData

/// Wall thickness for one size × schedule combination.
/// Weights, ID, areas, and volumes are derived — never stored.
@Model
final class PipeScheduleEntry {
    var designation: String  // "40", "STD", "XS", "10S", ...
    var wallInches: Double
    var standard: String     // "ASME B36.10M" or "ASME B36.19M"
    var size: NominalSize?

    init(designation: String, wallInches: Double, standard: String) {
        self.designation = designation
        self.wallInches = wallInches
        self.standard = standard
    }
}

extension PipeScheduleEntry {
    var odInches: Double { size?.odInches ?? 0 }
    var idInches: Double { max(odInches - 2 * wallInches, 0) }

    /// Plain-end weight, lb/ft (ASME B36.10M formula).
    var weightLbPerFt: Double { 10.69 * (odInches - wallInches) * wallInches }

    /// Weight including water fill, lb/ft.
    var waterFilledWeightLbPerFt: Double {
        weightLbPerFt + internalAreaSqIn * 12 * 0.036127 // lb/in³ water
    }

    var internalAreaSqIn: Double { .pi / 4 * idInches * idInches }

    /// External surface area for a length in feet → ft².
    func externalSurfaceSqFt(lengthFt: Double) -> Double {
        .pi * odInches / 12 * lengthFt
    }

    /// Internal surface area for a length in feet → ft².
    func internalSurfaceSqFt(lengthFt: Double) -> Double {
        .pi * idInches / 12 * lengthFt
    }

    /// Internal volume for a length in feet → ft³.
    func internalVolumeCuFt(lengthFt: Double) -> Double {
        internalAreaSqIn / 144 * lengthFt
    }
}
