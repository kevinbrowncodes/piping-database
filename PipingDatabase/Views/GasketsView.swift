import SwiftUI

struct GasketsView: View {
    @AppStorage(PrefKey.unitSystem) private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage(PrefKey.fractionDisplay) private var showFractions = false

    @State private var selectedClass: String
    @State private var selectedNPS: String
    @State private var fullFace = false

    init(preselect: [String: String] = [:]) {
        _selectedClass = State(initialValue: preselect["cl"] ?? "150")
        _selectedNPS = State(initialValue: preselect["nps"] ?? "2")
    }

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .imperial }
    private var file: GasketsFile? { ReferenceStore.shared.gaskets }
    private var gaskets: [GasketsFile.Gasket] { file?.gaskets ?? [] }

    private var classes: [String] {
        Array(Set(gaskets.map(\.class))).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }
    private var sizes: [String] {
        NPS.sorted(gaskets.filter { $0.class == selectedClass }.map(\.nps))
    }
    private var selection: GasketsFile.Gasket? {
        gaskets.first { $0.class == selectedClass && $0.nps == selectedNPS }
    }
    private var hasFullFace: Bool { selection?.ffOD != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let g = selection {
                        GasketDrawingView(gasket: g, fullFace: fullFace && hasFullFace,
                                          unit: unit, fractions: showFractions)
                            .frame(height: 230)
                            .contentShape(Rectangle())
                            .onTapGesture { showFractions.toggle() }
                        if hasFullFace {
                            Picker("Style", selection: $fullFace) {
                                Text("Flat ring (RF)").tag(false)
                                Text("Full face (FF)").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        dataCard(for: g)
                    } else {
                        ContentUnavailableView("No data", systemImage: "circle.slash")
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal)
            }
            pickers
        }
        .navigationTitle("Gaskets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(unit.toggleLabel) {
                    unitRaw = (unit == .imperial ? UnitSystem.metric : .imperial).rawValue
                }
                .font(.headline)
            }
        }
        .onChange(of: selectedClass) {
            if !sizes.contains(selectedNPS), let first = sizes.first { selectedNPS = first }
        }
    }

    private func fmt(_ inches: Double) -> String {
        Format.length(inches, unit: unit, fractions: showFractions)
    }

    private func dataCard(for g: GasketsFile.Gasket) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                labeled("ID", fmt(g.ringID))
                labeled(fullFace && hasFullFace ? "OD (FF)" : "OD (ring)",
                        fmt(fullFace ? (g.ffOD ?? g.ringOD) : g.ringOD))
            }
            if fullFace, let holes = g.ffHoles, let dia = g.ffHoleDia, let bc = g.ffBoltCircle {
                GridRow {
                    labeled("Bolt holes", "\(holes) × \(fmt(dia))")
                    labeled("BCD", fmt(bc))
                }
            }
            GridRow {
                labeled("Source", file?.standard ?? "ASME B16.21")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).bold()
        }
    }

    private var pickers: some View {
        HStack(spacing: 0) {
            Picker("Class", selection: $selectedClass) {
                ForEach(classes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.wheel)

            Picker("Size", selection: $selectedNPS) {
                ForEach(sizes, id: \.self) { Text("\($0)\"").tag($0) }
            }
            .pickerStyle(.wheel)
        }
        .frame(height: 130)
        .frame(maxWidth: 500)
        .background(.bar)
    }
}

/// Gasket face view: ring (annulus) or full-face with bolt holes.
struct GasketDrawingView: View {
    let gasket: GasketsFile.Gasket
    let fullFace: Bool
    let unit: UnitSystem
    var fractions: Bool = false

    private func fmt(_ v: Double) -> String {
        if unit == .imperial {
            return fractions ? Format.fractionalInches(v) : String(format: "%.2f", v)
        }
        return String(format: "%.1f", v * 25.4)
    }

    var body: some View {
        Canvas { ctx, size in
            let line = Color.primary.opacity(0.85)
            let dim = Color.green
            let center = CGPoint(x: size.width / 2, y: size.height / 2 + 8)
            let od = fullFace ? (gasket.ffOD ?? gasket.ringOD) : gasket.ringOD
            let outerR = min(size.width, size.height) * 0.36
            let scale = outerR / (od / 2)
            let innerR = gasket.ringID / 2 * scale

            ctx.fill(
                {
                    var p = Path()
                    p.addArc(center: center, radius: outerR, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
                    p.addArc(center: center, radius: innerR, startAngle: .zero, endAngle: .degrees(360), clockwise: true)
                    return p
                }(),
                with: .color(.primary.opacity(0.10)))
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: 2 * outerR, height: 2 * outerR)),
                       with: .color(line), lineWidth: 1.5)
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - innerR, y: center.y - innerR, width: 2 * innerR, height: 2 * innerR)),
                       with: .color(line), lineWidth: 1.5)

            if fullFace, let holes = gasket.ffHoles, let bc = gasket.ffBoltCircle, let hd = gasket.ffHoleDia {
                let bcR = bc / 2 * scale
                let holeR = max(hd / 2 * scale, 2)
                for i in 0..<holes {
                    let angle = Double(i) / Double(holes) * 2 * .pi - .pi / 2
                    let p = CGPoint(x: center.x + cos(angle) * bcR, y: center.y + sin(angle) * bcR)
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - holeR, y: p.y - holeR, width: 2 * holeR, height: 2 * holeR)),
                               with: .color(line), lineWidth: 1)
                }
            }

            let dimY = center.y - outerR - 14
            var d = Path()
            d.move(to: CGPoint(x: center.x - outerR, y: dimY))
            d.addLine(to: CGPoint(x: center.x + outerR, y: dimY))
            ctx.stroke(d, with: .color(dim), lineWidth: 1)
            ctx.draw(Text(fmt(od)).font(.system(.footnote, design: .monospaced)).foregroundStyle(dim),
                     at: CGPoint(x: center.x, y: dimY - 10))
            ctx.draw(Text("Ø \(fmt(gasket.ringID))").font(.system(.footnote, design: .monospaced)).foregroundStyle(dim),
                     at: CGPoint(x: center.x, y: center.y + outerR + 16))
        }
        .accessibilityLabel("Gasket drawing. Tap to toggle fractions.")
    }
}
