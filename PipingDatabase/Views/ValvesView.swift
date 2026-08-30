import SwiftUI

struct ValvesView: View {
    @AppStorage(PrefKey.unitSystem) private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage(PrefKey.fractionDisplay) private var showFractions = false

    @State private var selectedType: String
    @State private var selectedClass: String
    @State private var selectedFacing: String
    @State private var selectedNPS: String

    init(preselect: [String: String] = [:]) {
        _selectedType = State(initialValue: preselect["t"] ?? "gate")
        _selectedClass = State(initialValue: preselect["cl"] ?? "150")
        _selectedFacing = State(initialValue: preselect["f"] ?? "RF")
        _selectedNPS = State(initialValue: preselect["nps"] ?? "2")
    }

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .imperial }
    private var file: ValvesFile? { ReferenceStore.shared.valves }

    private static let typeLabels: [(String, String)] = [
        ("gate", "Gate"), ("globe", "Globe"), ("swingCheck", "Check"),
        ("ballFullReduced", "Ball"), ("ballFullBore", "Ball FB"),
    ]
    private static let facingLabels: [(String, String)] = [
        ("RF", "RF"), ("BW", "BW"), ("RTJ", "RTJ"),
    ]

    private var valves: [ValvesFile.Valve] { file?.valves ?? [] }

    private var classes: [String] {
        Array(Set(valves.filter { $0.type == selectedType }.map(\.class)))
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    private var facings: [String] {
        let set = Set(valves.filter { $0.type == selectedType && $0.class == selectedClass }.map(\.facing))
        return Self.facingLabels.map(\.0).filter(set.contains)
    }

    private var sizes: [String] {
        NPS.sorted(valves.filter {
            $0.type == selectedType && $0.class == selectedClass && $0.facing == selectedFacing
        }.map(\.nps))
    }

    private var selection: ValvesFile.Valve? {
        valves.first {
            $0.type == selectedType && $0.class == selectedClass
                && $0.facing == selectedFacing && $0.nps == selectedNPS
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let v = selection {
                        ValveDrawingView(valve: v, unit: unit, fractions: showFractions)
                            .frame(height: 240)
                            .contentShape(Rectangle())
                            .onTapGesture { showFractions.toggle() }
                        dataCard(for: v)
                    } else {
                        ContentUnavailableView(
                            "Not listed",
                            systemImage: "circle.slash",
                            description: Text("B16.10 does not list this combination — adjust class, facing, or size.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal)
            }
            pickers
        }
        .navigationTitle("Valves")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(unit.toggleLabel) {
                    unitRaw = (unit == .imperial ? UnitSystem.metric : .imperial).rawValue
                }
                .font(.headline)
            }
        }
        .onChange(of: selectedType) { reconcile() }
        .onChange(of: selectedClass) { reconcile() }
        .onChange(of: selectedFacing) { reconcile() }
    }

    private func reconcile() {
        if !classes.contains(selectedClass), let first = classes.first { selectedClass = first }
        if !facings.contains(selectedFacing), let first = facings.first { selectedFacing = first }
        if !sizes.contains(selectedNPS), let first = sizes.first { selectedNPS = first }
    }

    private func dataCard(for v: ValvesFile.Valve) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                VStack(alignment: .leading, spacing: 1) {
                    Text(v.facing == "BW" ? "End to end" : "Face to face")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(Format.length(v.inches, unit: unit, fractions: showFractions))
                        .font(.title3.monospacedDigit()).bold()
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Source").font(.caption2).foregroundStyle(.secondary)
                    Text(file?.standard ?? "ASME B16.10").font(.callout).bold()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var pickers: some View {
        HStack(spacing: 0) {
            Picker("Type", selection: $selectedType) {
                ForEach(Self.typeLabels, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.wheel)

            Picker("Class", selection: $selectedClass) {
                ForEach(classes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.wheel)

            Picker("Facing", selection: $selectedFacing) {
                ForEach(facings, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.wheel)

            Picker("Size", selection: $selectedNPS) {
                ForEach(sizes, id: \.self) { Text("\($0)\"").tag($0) }
            }
            .pickerStyle(.wheel)
        }
        .frame(height: 130)
        .frame(maxWidth: 700)
        .background(.bar)
    }
}

/// Schematic valve outline (bow-tie body + stem) with the face-to-face
/// dimension line — CAD-drawing style like the reference app.
struct ValveDrawingView: View {
    let valve: ValvesFile.Valve
    let unit: UnitSystem
    var fractions: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let dimColor = Color.green
            let lineColor = Color.primary.opacity(0.85)
            let centerlineColor = Color.cyan.opacity(0.7)

            let w = size.width * 0.6
            let h = min(size.height * 0.42, w * 0.6)
            let cx = size.width / 2
            let cy = size.height / 2 + 14
            let left = cx - w / 2
            let right = cx + w / 2

            // Bow-tie body
            var body = Path()
            body.move(to: CGPoint(x: left, y: cy - h / 2))
            body.addLine(to: CGPoint(x: left, y: cy + h / 2))
            body.addLine(to: CGPoint(x: cx, y: cy))
            body.addLine(to: CGPoint(x: right, y: cy + h / 2))
            body.addLine(to: CGPoint(x: right, y: cy - h / 2))
            body.addLine(to: CGPoint(x: cx, y: cy))
            body.closeSubpath()
            ctx.stroke(body, with: .color(lineColor), lineWidth: 1.5)

            // End flanges / weld ends
            for x in [left, right] {
                var end = Path()
                end.move(to: CGPoint(x: x, y: cy - h / 2 - 6))
                end.addLine(to: CGPoint(x: x, y: cy + h / 2 + 6))
                ctx.stroke(end, with: .color(lineColor), lineWidth: valve.facing == "BW" ? 1 : 3)
            }

            // Stem
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: cy))
            stem.addLine(to: CGPoint(x: cx, y: cy - h))
            stem.move(to: CGPoint(x: cx - 8, y: cy - h))
            stem.addLine(to: CGPoint(x: cx + 8, y: cy - h))
            ctx.stroke(stem, with: .color(lineColor), lineWidth: 1.5)

            // Centerline
            var center = Path()
            center.move(to: CGPoint(x: left - 16, y: cy))
            center.addLine(to: CGPoint(x: right + 16, y: cy))
            ctx.stroke(center, with: .color(centerlineColor),
                       style: StrokeStyle(lineWidth: 0.8, dash: [10, 3, 2, 3]))

            // Dimension line below
            let dimY = cy + h / 2 + 22
            var dim = Path()
            dim.move(to: CGPoint(x: left, y: dimY))
            dim.addLine(to: CGPoint(x: right, y: dimY))
            dim.move(to: CGPoint(x: left, y: cy + h / 2 + 8))
            dim.addLine(to: CGPoint(x: left, y: dimY + 4))
            dim.move(to: CGPoint(x: right, y: cy + h / 2 + 8))
            dim.addLine(to: CGPoint(x: right, y: dimY + 4))
            ctx.stroke(dim, with: .color(dimColor), lineWidth: 1)

            let text: String
            if unit == .imperial {
                text = fractions ? Format.fractionalInches(valve.inches)
                                 : String(format: "%.2f", valve.inches)
            } else {
                text = String(format: "%.1f", valve.inches * 25.4)
            }
            ctx.draw(Text(text).font(.system(.footnote, design: .monospaced)).foregroundStyle(dimColor),
                     at: CGPoint(x: cx, y: dimY + 12))
        }
        .accessibilityLabel("Valve outline with face-to-face dimension. Tap to toggle fractions.")
    }
}
