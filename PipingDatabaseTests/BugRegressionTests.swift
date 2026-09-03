import Testing
import Foundation
@testable import PipingDatabase

/// Regressions for the defects found in the 2026-09-03 device QA pass
/// (docs/bug/BUG-0001 …). One suite per ticket area, each test named for
/// what the app must keep doing.
struct BugRegressionTests {
    // MARK: BUG-0001 — bolt tightening sequence

    /// Sequence number at each hole position, clockwise from the top — the
    /// printed charts' 1-5-3-7-2-6-4-8 (8 bolts) and
    /// 1-11-6-16-2-12-7-17-3-13-8-18-4-14-9-19-5-15-10-20 (20 bolts),
    /// transposed from tightening order to hole labels.
    @Test(arguments: [
        (4, [1, 3, 2, 4]),
        (8, [1, 5, 3, 7, 2, 6, 4, 8]),
        (12, [1, 5, 9, 3, 7, 11, 2, 6, 10, 4, 8, 12]),
        (16, [1, 5, 9, 13, 3, 7, 11, 15, 2, 6, 10, 14, 4, 8, 12, 16]),
        (20, [1, 5, 9, 13, 17, 3, 7, 11, 15, 19, 2, 6, 10, 14, 18, 4, 8, 12, 16, 20]),
    ])
    func starSequence(count: Int, expected: [Int]) {
        #expect(BoltSequence.numbers(count: count) == expected)
    }

    /// Step 6 of the procedure: 0°-180°, then 90°-270°, then 45°-225°, then 135°-315°.
    @Test func eightBoltsFollowTheProcedureText() {
        let order = BoltSequence.order(count: 8)
        #expect(Array(order.prefix(8)) == [0, 4, 2, 6, 1, 5, 3, 7])
    }

    /// Every B16.5 / B16.47 bolt count is a multiple of four; the sequence
    /// must be a permutation with each bolt followed by its opposite.
    @Test func everyFlangeBoltCountIsAValidStar() throws {
        let file = try #require(ReferenceStore.shared.flanges)
        let counts = Set(file.classes.flatMap { $0.sizes.map(\.drilling.numHoles) })
        #expect(counts.count > 5)
        for n in counts {
            let order = BoltSequence.order(count: n)
            #expect(Set(order) == Set(0..<n), "\(n) bolts is not a permutation")
            for i in stride(from: 0, to: n, by: 2) {
                #expect((order[i] + n / 2) % n == order[i + 1], "\(n) bolts: pair \(i) not opposite")
            }
        }
    }

    @Test func oddCountsStillPermute() {
        for n in [1, 2, 3, 6, 10] {
            #expect(Set(BoltSequence.order(count: n)) == Set(0..<n))
        }
        #expect(BoltSequence.order(count: 0).isEmpty)
    }

    // MARK: BUG-0004 — legend captions

    @Test(arguments: [
        ("elbow90/elbow45: end to opposite outside face (overall, per diagram)", "End to opposite outside face"),
        ("minimum socket depth, printed 'D MIN.' (all SW tables: elbows, tees, crosses, laterals, quikLeg90, bossWithLip, coupling family)", "Minimum socket depth"),
        ("socket bore diameter, decimal (SW elbow90, elbow45, tee, cross, lateral; quikLeg90 run sockets)", "Socket bore diameter"),
        ("Minimum thickness of flange (catalog C). Inside perType.LJ (Classes 150/300) it is the separate minimum lap joint flange thickness; inside perType.WN / perType.blind of B16.47 (NPS 30-48) rows it is the printed WN / BLD thickness", "Minimum thickness of flange"),
        ("Bore of weld neck and socket weld flange (catalog B1); listed for Standard bore in Classes 150/300 and Extra-Strong bore in Class 600 unless purchaser specifies; omitted where catalog prints 'to be specified by purchaser' (Classes 125, 900, 1500, 2500)", "Bore of weld neck and socket weld flange"),
        ("Outside diameter of flange (catalog O.D.), inches", "Outside diameter of flange"),
        ("center to end, run (straight-tee tables label this column 'Center to Center'; reducing-tee tables 'Center to End' of run)", "Center to end, run"),
        ("Height from the branch (outlet) end of the fitting to the crotch at the run pipe, inches. Installed height per catalog: L = A + (run pipe OD)/2 + root gap.", "Height from the branch end of the fitting to the crotch at the run pipe"),
        ("Width across the fitting at the branch end (upper body), per catalog diagram, inches.", "Width across the fitting at the branch end"),
        ("Sockolet only: socket depth per catalog diagram, inches.", "Socket depth"),
        ("SW coupling family (coupling, halfCoupling, reducingCoupling, cap): outside diameter", "Outside diameter"),
        ("length (height) of cap, inches (printed as H in catalog; Schedule STD table value)", "Length of cap"),
        ("Diameter of weld neck at weld end (catalog K; Class 125: diameter of hub at bevel)", "Diameter of weld neck at weld end"),
    ])
    func legendCaptions(raw: String, expected: String) {
        #expect(LegendText.display(raw) == expected)
    }

    /// Every bundled legend must survive the cleaner as a short caption with
    /// no extraction vocabulary left in it.
    @Test func everyBundledLegendCleansUp() throws {
        let store = ReferenceStore.shared
        var legends = store.buttWeldLegend
        for file in [store.forged?.legend, store.flanges?.legend, store.olets?.legend].compactMap({ $0 }) {
            legends.merge(file) { a, _ in a }
        }
        #expect(legends.count > 80)
        for (key, raw) in legends {
            let caption = LegendText.display(raw)
            #expect(!caption.isEmpty, "\(key)")
            #expect(!caption.contains("("), "\(key): \(caption)")
            #expect(!caption.contains("perType"), "\(key): \(caption)")
            #expect(!caption.lowercased().contains("printed"), "\(key): \(caption)")
            #expect(!caption.hasSuffix("inches"), "\(key): \(caption)")
            #expect(caption.first?.isUppercase == true, "\(key): \(caption)")
            #expect(caption.count <= 90, "\(key): \(caption)")
        }
    }

    // MARK: BUG-0006 — numeric search tokens

    private func titles(_ query: String) -> [String] {
        SearchIndex.shared.search(query).map(\.title)
    }

    @Test func numbersMatchWholeTokensOnly() {
        #expect(SearchIndex.isNumeric("2"))
        #expect(SearchIndex.isNumeric("1/2"))
        #expect(SearchIndex.isNumeric("300"))
        #expect(!SearchIndex.isNumeric("wn"))
        #expect(!SearchIndex.isNumeric("b36.10"))

        let two300 = titles("2 300 wn")
        #expect(two300 == ["2\" 300# Weld Neck Flange"])

        // 1/8" pipe is DN 6, so it may follow — but never lead, and 16" never appears.
        let sch80six = titles("sch 80 6")
        #expect(sch80six.first == "6\" Sch 80 Pipe")
        #expect(sch80six.dropFirst().first == "6\" Sch 80S Pipe")
        #expect(!sch80six.contains { $0.hasPrefix("16\"") || $0.hasPrefix("26\"") })

        #expect(SearchIndex.tokenize("2 1/2 300 wn") == ["2 1/2", "300", "wn"])
        #expect(titles("2 1/2 300 wn") == ["2 1/2\" 300# Weld Neck Flange"])
        #expect(titles("1/2 300 wn") == ["1/2\" 300# Weld Neck Flange"])

        let olets = titles("weldolet 2")
        #expect(!olets.isEmpty)
        #expect(olets.allSatisfy { $0.hasPrefix("2\" ") })
    }

    @Test func wordsStillMatchAnywhere() {
        #expect(titles("gate 600").first == "2\" 600# Gate Valve")
        #expect(!titles("b36.19 1/2").isEmpty)                 // standard names stay searchable
        #expect(titles("dn 150 sch 40").first == "6\" Sch 40 Pipe")
        #expect(titles("").isEmpty)
    }

    @Test func oletSummaryReadsNaturally() throws {
        let olets = try #require(ReferenceStore.shared.olets).olets
        let ranged = try #require(olets.first { $0.runFrom != nil && $0.runFrom != $0.runTo })
        #expect(ranged.runSummary.hasPrefix("Run "))
        let unranged = try #require(olets.first { $0.runFrom == nil })
        #expect(unranged.runSummary == "Order to run size")
        #expect(!SearchIndex.shared.entries.contains { $0.subtitle.contains("Run Order") })
    }

    // MARK: BUG-0003 — flange type follows the row

    @Test func flangeTypeReconciles() {
        #expect(FlangesView.reconciledType("LJ", available: ["WN", "blind"]) == "WN")
        #expect(FlangesView.reconciledType("blind", available: ["WN", "blind"]) == "blind")
        #expect(FlangesView.reconciledType("TH", available: []) == "TH")
    }

    @Test func class125OffersOnlyWeldNeckAndSlipOn() throws {
        let file = try #require(ReferenceStore.shared.flanges)
        let c125 = try #require(file.classes.first { $0.class == "125" })
        for size in c125.sizes {
            let present = Set((size.perType ?? [:]).keys).union((size.weights ?? [:]).keys)
            #expect(present.isSubset(of: ["WN", "SO"]), "\(size.nps)")
        }
    }

    // MARK: BUG-0008 — source labels

    @Test func flangeSourceLabelPerRow() throws {
        let file = try #require(ReferenceStore.shared.flanges)
        let two150 = try #require(file.classes.first { $0.class == "150" }?.sizes.first { $0.nps == "2" })
        #expect(two150.sourceLabel(class: "150") == "ASME B16.5")
        #expect(two150.sourceLabel(class: "125") == "ASME B16.1")
        let thirtyA = try #require(file.classes.first { $0.class == "150" }?.sizes.first { $0.series == "B16.47 Series A" })
        #expect(thirtyA.sourceLabel(class: "150") == "B16.47 Series A")
    }
}
