import Testing
import Foundation
@testable import PipingDatabase

/// Layer 2 of docs/TESTING.md: derived values reproduce published columns
/// and the reference app's displayed values.
struct FormulaTests {
    private func entry(od: Double, wall: Double) -> PipeScheduleEntry {
        let size = NominalSize(nps: "test", sortValue: 0, dn: 0, odInches: od)
        let e = PipeScheduleEntry(designation: "T", wallInches: wall, standard: "test")
        e.size = size
        size.entries.append(e)
        return e
    }

    /// Golden weights from the Weldbend catalog's published Weight-Per-Foot
    /// column (pp. 138–143). Formula must reproduce them within rounding.
    @Test(arguments: [
        (0.840, 0.109, 0.85),    // 1/2 Sch 40
        (2.375, 0.154, 3.66),    // 2 STD
        (8.625, 0.875, 72.49),   // 8 XXS
        (12.750, 0.375, 49.61),  // 12 STD
        (24.000, 2.344, 542.67), // 24 Sch 160
        (36.000, 0.750, 282.62), // 36 Sch 40
    ])
    func weightFormulaMatchesPublished(od: Double, wall: Double, published: Double) {
        let w = entry(od: od, wall: wall).weightLbPerFt
        #expect(abs(w - published) / published < 0.005, "got \(w), want \(published)")
    }

    /// Reference-app parity: values the original app displays for
    /// 1/8" Sch 10 (validated from screenshots during recon).
    @Test func referenceAppParity() {
        let e = entry(od: 0.405, wall: 0.049)
        #expect(abs(e.idInches - 0.307) < 0.0005)
        #expect(abs(e.weightLbPerFt - 0.19) < 0.005)
        #expect(abs(e.waterFilledWeightLbPerFt - 0.22) < 0.005)
        #expect(abs(e.internalVolumeCuFt(lengthFt: 1) - 0.000514) < 0.000002)
        #expect(abs(e.externalSurfaceSqFt(lengthFt: 1) - 0.106) < 0.001)
    }

    /// Weldbend also publishes water weight and surface areas — spot check.
    @Test func weldbendDerivedColumns() {
        let two = entry(od: 2.375, wall: 0.154) // 2" STD
        #expect(abs(two.externalSurfaceSqFt(lengthFt: 1) - 0.622) < 0.001)
        #expect(abs(two.internalSurfaceSqFt(lengthFt: 1) - 0.541) < 0.001)
        #expect(abs((two.waterFilledWeightLbPerFt - two.weightLbPerFt) - 1.454) < 0.01)
    }

    @Test func unitConversions() {
        #expect(Format.length(1.0, unit: .metric) == "25.40 mm")
        #expect(Format.length(0.109, unit: .imperial) == "0.109 in")
        #expect(Format.linearWeight(1.0, unit: .metric) == "1.49 kg/m")
        #expect(Format.volume(1.0, unit: .metric) == "28.3168 L")
    }

    @Test func edgeCases() {
        let e = entry(od: 0.405, wall: 0.049)
        #expect(e.internalVolumeCuFt(lengthFt: 0) == 0)
        let orphan = PipeScheduleEntry(designation: "X", wallInches: 0.1, standard: "test")
        #expect(orphan.odInches == 0)
        #expect(orphan.idInches == 0)   // clamped, never negative
    }
}
