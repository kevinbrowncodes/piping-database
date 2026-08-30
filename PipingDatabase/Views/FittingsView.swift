import SwiftUI

struct FittingsView: View {
    @AppStorage(PrefKey.unitSystem) private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage(PrefKey.fractionDisplay) private var showFractions = false

    @State private var connection: String
    @State private var selectedType: String
    @State private var selectedClass: String
    @State private var selectedNPS: String
    @State private var selectedNPS2: String

    init(preselect: [String: String] = [:]) {
        _connection = State(initialValue: preselect["c"] ?? "BW")
        _selectedType = State(initialValue: preselect["t"] ?? "elbow90LR")
        _selectedClass = State(initialValue: preselect["cl"] ?? "3000")
        _selectedNPS = State(initialValue: preselect["nps"] ?? "2")
        _selectedNPS2 = State(initialValue: preselect["nps2"] ?? "")
    }

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .imperial }
    private var store: ReferenceStore { .shared }

    static let bwTypeLabels: [(String, String)] = [
        ("elbow90LR", "90° Elbow LR"), ("elbow90SR", "90° Elbow SR"),
        ("elbow90LR_reducing", "90° Red. Elbow"), ("elbow90_3R", "90° Elbow 3R"),
        ("elbow45LR", "45° Elbow LR"), ("elbow45_3R", "45° Elbow 3R"),
        ("return180LR", "180° Return LR"), ("return180SR", "180° Return SR"),
        ("tee", "Tee"), ("tee_reducing", "Reducing Tee"),
        ("reducer_concentric", "Conc. Reducer"), ("reducer_eccentric", "Ecc. Reducer"),
        ("cap", "Cap"), ("lapJointStubEnd", "LJ Stub End"),
    ]

    private var pool: [FittingsFile.Fitting] {
        connection == "BW"
            ? store.buttWeldFittings
            : (store.forged?.fittings ?? []).filter { $0.connection == connection }
    }

    private var legend: [String: String] {
        connection == "BW" ? store.buttWeldLegend : (store.forged?.legend ?? [:])
    }

    static let forgedTypeLabels: [(String, String)] = [
        ("elbow90", "90° Elbow"), ("elbow45", "45° Elbow"), ("streetElbow", "Street Elbow"),
        ("tee", "Tee"), ("cross", "Cross"), ("lateral", "Lateral"),
        ("coupling", "Coupling"), ("halfCoupling", "Half Coupling"),
        ("reducingCoupling", "Red. Coupling"), ("cap", "Cap"),
        ("quikLeg90", "QuikLeg 90"), ("bossWithLip", "Boss w/ Lip"),
        ("plugRound", "Plug (Round)"), ("plugHex", "Plug (Hex)"), ("plugSquare", "Plug (Square)"),
        ("bushingHex", "Bushing (Hex)"), ("bushingFlush", "Bushing (Flush)"),
        ("union", "Union"),
    ]

    private var types: [(String, String)] {
        let present = Set(pool.map(\.type))
        if connection == "BW" {
            return Self.bwTypeLabels.filter { present.contains($0.0) }
        }
        return Self.forgedTypeLabels.filter { present.contains($0.0) }
            + present.subtracting(Self.forgedTypeLabels.map(\.0)).sorted().map { ($0, $0) }
    }

    private var typed: [FittingsFile.Fitting] {
        pool.filter { $0.type == selectedType && (connection == "BW" || $0.class == selectedClass) }
    }

    private var classes: [String] {
        guard connection != "BW" else { return [] }
        return Array(Set(pool.filter { $0.type == selectedType }.compactMap(\.class)))
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    private var sizes: [String] { NPS.sorted(typed.map(\.nps)) }

    private var secondSizes: [String] {
        NPS.sorted(typed.filter { $0.nps == selectedNPS }.compactMap(\.nps2))
    }

    private var selection: FittingsFile.Fitting? {
        let matches = typed.filter { $0.nps == selectedNPS }
        if secondSizes.isEmpty { return matches.first }
        return matches.first { $0.nps2 == selectedNPS2 } ?? matches.first
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let f = selection {
                        FittingDrawingView(fitting: f, unit: unit, fractions: showFractions)
                            .frame(height: 210)
                            .contentShape(Rectangle())
                            .onTapGesture { showFractions.toggle() }
                        dimsCard(for: f)
                        if let weights = f.weights, !weights.isEmpty {
                            weightsCard(weights)
                        } else if let w = f.weight {
                            weightsCard(["–": w])
                        }
                    } else {
                        ContentUnavailableView("No data", systemImage: "circle.slash")
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal)
            }
            pickers
        }
        .navigationTitle("Fittings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(unit.toggleLabel) {
                    unitRaw = (unit == .imperial ? UnitSystem.metric : .imperial).rawValue
                }
                .font(.headline)
            }
        }
        .onChange(of: connection) { reconcile() }
        .onChange(of: selectedType) { reconcile() }
        .onChange(of: selectedClass) { reconcile() }
        .onChange(of: selectedNPS) { reconcileSecond() }
    }

    private func reconcile() {
        if !types.contains(where: { $0.0 == selectedType }), let first = types.first {
            selectedType = first.0
        }
        if connection != "BW", !classes.contains(selectedClass), let first = classes.first {
            selectedClass = first
        }
        if !sizes.contains(selectedNPS), let first = sizes.first { selectedNPS = first }
        reconcileSecond()
    }

    private func reconcileSecond() {
        if !secondSizes.contains(selectedNPS2) { selectedNPS2 = secondSizes.first ?? "" }
    }

    private func fmt(_ inches: Double) -> String {
        Format.length(inches, unit: unit, fractions: showFractions)
    }

    /// Forged legend uses family-suffixed keys (A_elbow, E_sw, F_cap_SW…);
    /// resolve a row's plain letter against the fitting's type/connection.
    private func legendText(_ key: String, for f: FittingsFile.Fitting) -> String {
        if let direct = legend[key] { return direct }
        let context = "\(f.type) \(f.connection ?? "")".lowercased()
        let candidates = legend.keys.filter { $0.hasPrefix("\(key)_") }
        let best = candidates.first {
            let suffix = $0.dropFirst(key.count + 1).lowercased()
            return suffix.split(separator: "_").allSatisfy { context.contains($0) }
        } ?? candidates.first
        return best.flatMap { legend[$0] } ?? ""
    }

    private func dimsCard(for f: FittingsFile.Fitting) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(f.dims.keys.sorted(), id: \.self) { key in
                HStack(alignment: .firstTextBaseline) {
                    Text(key.replacingOccurrences(of: "_", with: " "))
                        .font(.callout.monospaced()).bold()
                        .frame(width: 52, alignment: .leading)
                    Text(legendText(key, for: f)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(fmt(f.dims[key] ?? 0)).font(.callout.monospacedDigit()).bold()
                }
            }
            Divider()
            Text(connection == "BW" ? "ASME B16.9 · Weldbend" : "ASME B16.11 · Bonney Forge")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func weightsCard(_ weights: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weight").font(.caption2).foregroundStyle(.secondary)
            let keys = weights.keys.sorted { ScheduleOrder.index(of: $0) < ScheduleOrder.index(of: $1) }
            HStack(spacing: 18) {
                ForEach(keys, id: \.self) { k in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(k == "–" ? "each" : "Sch \(k)").font(.caption2).foregroundStyle(.secondary)
                        Text(String(format: "%.2f lb", weights[k] ?? 0))
                            .font(.callout.monospacedDigit()).bold()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var pickers: some View {
        HStack(spacing: 0) {
            Picker("End", selection: $connection) {
                Text("BW").tag("BW")
                Text("SW").tag("SW")
                Text("TH").tag("TH")
            }
            .pickerStyle(.wheel)
            .frame(width: 70)

            Picker("Type", selection: $selectedType) {
                ForEach(types, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.wheel)

            if connection != "BW" {
                Picker("Class", selection: $selectedClass) {
                    ForEach(classes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
            }

            Picker("Size", selection: $selectedNPS) {
                ForEach(sizes, id: \.self) { Text("\($0)\"").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 90)

            if !secondSizes.isEmpty {
                Picker("Size 2", selection: $selectedNPS2) {
                    ForEach(secondSizes, id: \.self) { Text("\($0)\"").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 90)
            }
        }
        .frame(height: 130)
        .frame(maxWidth: 700)
        .background(.bar)
    }
}

/// Schematic per-type fitting outlines with the principal dimension called out.
struct FittingDrawingView: View {
    let fitting: FittingsFile.Fitting
    let unit: UnitSystem
    var fractions: Bool = false

    private func fmt(_ v: Double) -> String {
        if unit == .imperial {
            return fractions ? Format.fractionalInches(v) : String(format: "%.2f", v)
        }
        return String(format: "%.1f", v * 25.4)
    }

    private var principal: (String, Double)? {
        for key in ["A", "C", "H", "E", "V", "W", "L", "B", "F"] {
            if let v = fitting.dims[key] { return (key, v) }
        }
        return fitting.dims.sorted { $0.key < $1.key }.first.map { ($0.key, $0.value) }
    }

    var body: some View {
        Canvas { ctx, size in
            let line = Color.primary.opacity(0.85)
            let dim = Color.green
            let w = min(size.width, size.height * 1.6) * 0.55
            let cx = size.width / 2
            let cy = size.height / 2 + 6
            let tube = w * 0.28

            var path = Path()
            switch fitting.type {
            case let t where t.hasPrefix("elbow90"):
                let r = w * 0.62
                let c = CGPoint(x: cx - r / 2, y: cy + r / 2)
                path.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
                path.addArc(center: c, radius: max(r - tube, 4), startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true)
                path.closeSubpath()
            case let t where t.hasPrefix("elbow45"):
                let r = w * 0.9
                let c = CGPoint(x: cx - r / 2, y: cy + r / 2)
                path.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(-45), clockwise: false)
                path.addArc(center: c, radius: max(r - tube, 4), startAngle: .degrees(-45), endAngle: .degrees(-90), clockwise: true)
                path.closeSubpath()
            case let t where t.hasPrefix("return180"):
                let r = w * 0.45
                let c = CGPoint(x: cx, y: cy + r / 3)
                path.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addArc(center: c, radius: max(r - tube, 4), startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
                path.closeSubpath()
            case let t where t.hasPrefix("tee"):
                let half = w / 2
                path.move(to: CGPoint(x: cx - half, y: cy - tube / 2))
                path.addLine(to: CGPoint(x: cx - tube / 2, y: cy - tube / 2))
                path.addLine(to: CGPoint(x: cx - tube / 2, y: cy - half * 0.8))
                path.addLine(to: CGPoint(x: cx + tube / 2, y: cy - half * 0.8))
                path.addLine(to: CGPoint(x: cx + tube / 2, y: cy - tube / 2))
                path.addLine(to: CGPoint(x: cx + half, y: cy - tube / 2))
                path.addLine(to: CGPoint(x: cx + half, y: cy + tube / 2))
                path.addLine(to: CGPoint(x: cx - half, y: cy + tube / 2))
                path.closeSubpath()
            case let t where t.hasPrefix("reducer"):
                let half = w / 2
                let big = tube, small = tube * 0.55
                let eccentric = fitting.type == "reducer_eccentric"
                let bottomBig = cy + big / 2
                path.move(to: CGPoint(x: cx - half, y: cy - big / 2))
                path.addLine(to: CGPoint(x: cx + half, y: eccentric ? bottomBig - small : cy - small / 2))
                path.addLine(to: CGPoint(x: cx + half, y: eccentric ? bottomBig : cy + small / 2))
                path.addLine(to: CGPoint(x: cx - half, y: bottomBig))
                path.closeSubpath()
            case "cap":
                let half = w * 0.3
                path.move(to: CGPoint(x: cx - half / 2, y: cy - tube))
                path.addLine(to: CGPoint(x: cx - half / 2, y: cy + tube))
                path.addQuadCurve(to: CGPoint(x: cx + half, y: cy),
                                  control: CGPoint(x: cx + half, y: cy + tube))
                // mirror top
                path.move(to: CGPoint(x: cx - half / 2, y: cy - tube))
                path.addQuadCurve(to: CGPoint(x: cx + half, y: cy),
                                  control: CGPoint(x: cx + half, y: cy - tube))
            default:
                path.addRect(CGRect(x: cx - w / 2, y: cy - tube / 2, width: w, height: tube))
            }
            ctx.stroke(path, with: .color(line), lineWidth: 1.5)

            if let (key, value) = principal {
                let dimY = cy + size.height * 0.32
                var d = Path()
                d.move(to: CGPoint(x: cx - w / 2, y: dimY))
                d.addLine(to: CGPoint(x: cx + w / 2, y: dimY))
                ctx.stroke(d, with: .color(dim), lineWidth: 1)
                ctx.draw(Text("\(key)  \(fmt(value))")
                    .font(.system(.footnote, design: .monospaced)).foregroundStyle(dim),
                         at: CGPoint(x: cx, y: dimY + 12))
            }
        }
        .accessibilityLabel("Fitting outline drawing. Tap to toggle fractions.")
    }
}
