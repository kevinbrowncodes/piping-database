import Testing
import Foundation
@testable import PipingDatabase

/// Layer 1 checks for the extracted module datasets. Golden values are typed
/// from the governing standards' published tables (independent of the
/// catalog extraction path).
struct ReferenceDataTests {
    static let store = ReferenceStore.shared

    // MARK: Fittings — butt-weld (B16.9)

    @Test func elbowsDatasetLoads() throws {
        let f = try #require(Self.store.elbows)
        #expect(f.fittings.count == 179)
        #expect(f.standard == "ASME B16.9")
        let counts = Dictionary(grouping: f.fittings, by: \.type).mapValues(\.count)
        #expect(counts["elbow90LR"] == 24)
        #expect(counts["elbow90LR_reducing"] == 33)
        #expect(counts["return180SR"] == 18)
    }

    @Test func elbowGoldens() throws {
        let f = try #require(Self.store.elbows)
        // B16.9 published: 90 LR center-to-end = 1.5×NPS (2"→3.00);
        // 90 SR center-to-end = NPS; 45 LR 4"→2.50; 180 LR center-to-center 4"→12.00.
        #expect(f.fittings.first { $0.type == "elbow90LR" && $0.nps == "2" }?.dims["C"] == 3.00)
        #expect(f.fittings.first { $0.type == "elbow90SR" && $0.nps == "4" }?.dims["C"] == 4.00)
        #expect(f.fittings.first { $0.type == "elbow45LR" && $0.nps == "4" }?.dims["A"] == 2.50)
        #expect(f.fittings.first { $0.type == "return180LR" && $0.nps == "4" }?.dims["V"] == 12.00)
    }

    @Test func teesDatasetLoads() throws {
        let f = try #require(Self.store.tees)
        #expect(f.fittings.count == 124)
        let straight = f.fittings.filter { $0.type == "tee" }
        #expect(straight.count == 24)
        // B16.9 published: 4" tee C = 4.12; 6" tee C = 5.62.
        #expect(straight.first { $0.nps == "4" }?.dims["R"] == 4.12)
        #expect(straight.first { $0.nps == "6" }?.dims["R"] == 5.62)
        // Every reducing tee outlet is smaller than its run.
        for t in f.fittings where t.type == "tee_reducing" {
            #expect(NPS.value(t.nps2 ?? "") < NPS.value(t.nps), "\(t.nps)x\(t.nps2 ?? "?")")
        }
    }

    @Test func reducersCapsStubsDatasetLoads() throws {
        let f = try #require(Self.store.reducersCapsStubs)
        #expect(f.fittings.count == 242)
        // B16.9 published: 4x2 reducer length = 4.00; 4" cap length = 2.50.
        #expect(f.fittings.first { $0.type == "reducer_concentric" && $0.nps == "4" && $0.nps2 == "2" }?.dims["L"] == 4.00)
        #expect(f.fittings.first { $0.type == "cap" && $0.nps == "4" }?.dims["E"] == 2.50)
        // Concentric/eccentric parity.
        let conc = f.fittings.filter { $0.type == "reducer_concentric" }.count
        let ecc = f.fittings.filter { $0.type == "reducer_eccentric" }.count
        #expect(conc == ecc)
    }

    // MARK: Fittings — forged (B16.11)

    @Test func forgedDatasetLoads() throws {
        let f = try #require(Self.store.forged)
        #expect(f.fittings.count == 606)
        #expect(f.standard == "ASME B16.11")
        for fit in f.fittings {
            #expect(fit.connection == "SW" || fit.connection == "TH", "\(fit.id)")
            #expect(fit.class != nil, "\(fit.id)")
        }
        // B16.11 published: SW 3000 tee NPS 3/4 center-to-end A = 1.50.
        let tee34 = f.fittings.first {
            $0.type == "tee" && $0.connection == "SW" && $0.class == "6000" && $0.nps == "3/4"
        }
        #expect(tee34?.dims["A"] == 1.5)
    }

    // MARK: Gaskets (B16.21)

    @Test func gasketsDatasetLoads() throws {
        let f = try #require(Self.store.gaskets)
        #expect(f.gaskets.count == 99)
        let counts = Dictionary(grouping: f.gaskets, by: \.class).mapValues(\.count)
        #expect(counts == ["150": 20, "300": 20, "400": 20, "600": 20, "900": 19])
        // B16.21 published: 2" Class 150 ring gasket 2.38 ID × 4.12 OD.
        let two150 = f.gaskets.first { $0.class == "150" && $0.nps == "2" }
        #expect(two150?.ringID == 2.38)
        #expect(two150?.ringOD == 4.12)
        for g in f.gaskets {
            #expect(g.ringOD > g.ringID, "\(g.class) \(g.nps)")
            if let ff = g.ffOD { #expect(ff > g.ringOD, "\(g.class) \(g.nps)") }
        }
    }

    /// Cross-dataset consistency: full-face gasket drilling must agree with
    /// the flange drilling extracted from a completely different catalog.
    @Test func gasketDrillingMatchesFlangeDrilling() throws {
        let gaskets = try #require(Self.store.gaskets)
        let flanges = try #require(Self.store.flanges)
        var compared = 0
        for g in gaskets.gaskets {
            guard let bc = g.ffBoltCircle, let holes = g.ffHoles else { continue }
            guard let cls = flanges.classes.first(where: { $0.class == g.class }),
                  let flange = cls.sizes.first(where: { $0.nps == g.nps && $0.series == nil })
            else { continue }
            #expect(holes == flange.drilling.numHoles, "\(g.class) \(g.nps) holes")
            #expect(abs(bc - flange.drilling.boltCircle) <= 0.011, "\(g.class) \(g.nps) BC \(bc) vs \(flange.drilling.boltCircle)")
            compared += 1
        }
        // FF data spans classes 150/300/400/600; flange data lacks 400 → 3×20 rows.
        #expect(compared == 60, "expected 60 overlapping rows, compared \(compared)")
    }

    // MARK: P-T ratings & bolt torque

    @Test func ptRatingsLoad() throws {
        let pt = try #require(Self.store.ptRatings)
        // B16.5 Group 1.1 published goldens.
        #expect(pt.rating(class: "150", tempF: 100) == 285)
        #expect(pt.rating(class: "300", tempF: 100) == 740)
        #expect(pt.rating(class: "2500", tempF: 1000) == 715)
        // Ratings decrease with temperature for every class.
        for (cls, series) in pt.classes {
            #expect(series.count == pt.temperaturesF.count, "\(cls)")
            #expect(series == series.sorted(by: >), "non-decreasing ratings in \(cls)")
        }
    }

    @Test func boltTorqueLoads() throws {
        let t = try #require(Self.store.boltTorque)
        #expect(t.torque(boltDia: "3/4", stressPsi: 50000) == 167)
        #expect(t.torque(boltDia: "5/8", stressPsi: 30000) == 60)
        #expect(t.procedure.count == 7)
        // Torque grows with diameter at every stress level.
        for stress in t.stressesPsi {
            let row = try #require(t.torqueFtLbs[String(stress)])
            #expect(row == row.sorted(), "\(stress)")
            #expect(row.count == t.boltDiameters.count)
        }
        // Linear-with-stress consistency (the property used to validate the source).
        let r30 = try #require(t.torqueFtLbs["30000"])
        let r60 = try #require(t.torqueFtLbs["60000"])
        for (a, b) in zip(r30, r60) {
            #expect(abs(Double(b) - 2 * Double(a)) / Double(b) < 0.02)
        }
    }

    // MARK: Valves (B16.10)

    @Test func valvesDatasetLoads() throws {
        let f = try #require(Self.store.valves)
        #expect(f.valves.count == 821)
        // Chart headers: class 600 ball is full bore.
        #expect(!f.valves.contains { $0.type == "ballFullReduced" && $0.class == "600" })
        // B16.10 published goldens.
        func dim(_ type: String, _ cls: String, _ facing: String, _ nps: String) -> Double? {
            f.valves.first { $0.type == type && $0.class == cls && $0.facing == facing && $0.nps == nps }?.inches
        }
        #expect(dim("gate", "150", "RF", "2") == 7.0)
        #expect(dim("gate", "150", "BW", "2") == 8.5)
        #expect(dim("gate", "600", "RF", "2") == 11.5)
        #expect(dim("swingCheck", "150", "RF", "2") == 8.0)
        #expect(dim("globe", "150", "RF", "2") == 8.0)
    }

    // MARK: Line blanks (B16.48)

    @Test func lineBlanksDatasetLoads() throws {
        let f = try #require(Self.store.lineBlanks)
        #expect(f.blanks.count == 111)
        let b150half = f.blanks.first { $0.class == "150" && $0.nps == "1/2" }
        #expect(b150half?.odO == 1.75)
        #expect(b150half?.thk == 0.12)
        let b300x24 = f.blanks.first { $0.class == "300" && $0.nps == "24" }
        #expect(b300x24?.thk == 2.00)
        for b in f.blanks {
            #expect(b.odO > b.idB, "\(b.class) \(b.nps)")
        }
    }

    // MARK: Flanges (B16.5 + B16.47)

    @Test func flangesDatasetLoads() throws {
        let f = try #require(Self.store.flanges)
        let counts = Dictionary(uniqueKeysWithValues: f.classes.map { ($0.class, $0.sizes.count) })
        #expect(counts == ["125": 6, "150": 28, "300": 28, "600": 26, "900": 25, "1500": 19, "2500": 14])
        // B16.5 published drilling goldens.
        let c150 = f.classes.first { $0.class == "150" }
        let two150 = c150?.sizes.first { $0.nps == "2" && $0.series == nil }
        #expect(two150?.dims["O"] == 6.00)
        #expect(two150?.drilling.boltCircle == 4.75)
        #expect(two150?.drilling.numHoles == 4)
        #expect(two150?.drilling.boltDia == "5/8")
        let six300 = f.classes.first { $0.class == "300" }?.sizes.first { $0.nps == "6" && $0.series == nil }
        #expect(six300?.dims["O"] == 12.50)
        #expect(six300?.drilling.numHoles == 12)
        #expect(six300?.drilling.boltDia == "3/4")
        // B16.47 coverage: both series present at NPS 30 in class 150.
        let thirty = c150?.sizes.filter { $0.nps == "30" } ?? []
        #expect(thirty.count == 2)
        // Structural: bolt circle inside OD, holes in multiples of 4.
        for cls in f.classes {
            for s in cls.sizes {
                if let od = s.dims["O"] {
                    #expect(s.drilling.boltCircle < od, "\(cls.class) \(s.key)")
                }
                #expect(s.drilling.numHoles > 0 && s.drilling.numHoles % 4 == 0, "\(cls.class) \(s.key)")
            }
        }
    }

    // MARK: Branch connections (MSS SP-97)

    @Test func oletsDatasetLoads() throws {
        let f = try #require(Self.store.olets)
        #expect(f.olets.count == 188)
        let counts = Dictionary(grouping: f.olets, by: { "\($0.type)/\($0.class)" }).mapValues(\.count)
        #expect(counts["weldolet/STD"] == 48)
        #expect(counts["sockolet/3000"] == 27)
        #expect(counts["thredolet/3000"] == 27)
        for o in f.olets {
            for (k, v) in o.dims { #expect(v > 0, "\(o.id) \(k)") }
        }
    }
}
