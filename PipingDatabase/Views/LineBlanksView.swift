import SwiftUI

struct LineBlanksView: View {
    @AppStorage(PrefKey.unitSystem) private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage(PrefKey.fractionDisplay) private var showFractions = false

    @State private var selectedClass: String
    @State private var selectedNPS: String

    init(preselect: [String: String] = [:]) {
        _selectedClass = State(initialValue: preselect["cl"] ?? "150")
        _selectedNPS = State(initialValue: preselect["nps"] ?? "2")
    }

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .imperial }
    private var file: LineBlanksFile? { ReferenceStore.shared.lineBlanks }
    private var blanks: [LineBlanksFile.Blank] { file?.blanks ?? [] }

    private var classes: [String] {
        Array(Set(blanks.map(\.class))).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }
    private var sizes: [String] {
        NPS.sorted(blanks.filter { $0.class == selectedClass }.map(\.nps))
    }
    private var selection: LineBlanksFile.Blank? {
        blanks.first { $0.class == selectedClass && $0.nps == selectedNPS }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let b = selection {
                        Figure8DrawingView(blank: b, unit: unit, fractions: showFractions)
                            .frame(height: 230)
                            .contentShape(Rectangle())
                            .onTapGesture { showFractions.toggle() }
                        dataCard(for: b)
                    } else {
                        ContentUnavailableView("No data", systemImage: "circle.slash")
                    }
                }
                .padding(.horizontal)
            }
            pickers
        }
        .navigationTitle("Line Blanks")
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

    private func dataCard(for b: LineBlanksFile.Blank) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                labeled("OD", fmt(b.odO))
                labeled("ID (spacer)", fmt(b.idB))
            }
            GridRow {
                labeled("Thickness", fmt(b.thk))
                labeled("Source", file?.standard ?? "ASME B16.48")
            }
            GridRow {
                if let w = b.blindWeight {
                    labeled("Blind wt.", String(format: "%.2f lb", w))
                }
                if let w = b.spacerWeight {
                    labeled("Spacer wt.", String(format: "%.2f lb", w))
                }
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
                ForEach(classes, id: \.self) { Text("\($0) RF").tag($0) }
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

/// Figure-8 (spectacle blind) front view: solid disc + ring, dimension lines.
struct Figure8DrawingView: View {
    let blank: LineBlanksFile.Blank
    let unit: UnitSystem
    var fractions: Bool = false

    private func fmt(_ inches: Double) -> String {
        if unit == .imperial {
            return fractions ? Format.fractionalInches(inches) : String(format: "%.3f", inches)
        }
        return String(format: "%.1f", inches * 25.4)
    }

    var body: some View {
        Canvas { ctx, size in
            let lineColor = Color.primary.opacity(0.85)
            let dimColor = Color.green
            let centerColor = Color.cyan.opacity(0.7)

            let r = min(size.width / 4.6, size.height / 2.8)
            let cy = size.height / 2 + 8
            let leftC = CGPoint(x: size.width / 2 - r - 4, y: cy)
            let rightC = CGPoint(x: size.width / 2 + r + 4, y: cy)

            // Solid blind disc
            ctx.stroke(Path(ellipseIn: CGRect(x: leftC.x - r, y: cy - r, width: 2 * r, height: 2 * r)),
                       with: .color(lineColor), lineWidth: 1.5)
            // Spacer ring
            ctx.stroke(Path(ellipseIn: CGRect(x: rightC.x - r, y: cy - r, width: 2 * r, height: 2 * r)),
                       with: .color(lineColor), lineWidth: 1.5)
            let innerR = r * (blank.idB / blank.odO)
            ctx.stroke(Path(ellipseIn: CGRect(x: rightC.x - innerR, y: cy - innerR, width: 2 * innerR, height: 2 * innerR)),
                       with: .color(lineColor), lineWidth: 1.5)

            // Tie bar
            var tie = Path()
            tie.move(to: CGPoint(x: leftC.x + r - 2, y: cy - 3))
            tie.addLine(to: CGPoint(x: rightC.x - r + 2, y: cy - 3))
            tie.move(to: CGPoint(x: leftC.x + r - 2, y: cy + 3))
            tie.addLine(to: CGPoint(x: rightC.x - r + 2, y: cy + 3))
            ctx.stroke(tie, with: .color(lineColor), lineWidth: 1)

            // Centerlines
            var center = Path()
            center.move(to: CGPoint(x: leftC.x - r - 12, y: cy))
            center.addLine(to: CGPoint(x: rightC.x + r + 12, y: cy))
            ctx.stroke(center, with: .color(centerColor),
                       style: StrokeStyle(lineWidth: 0.8, dash: [10, 3, 2, 3]))

            // OD dimension over the blind disc
            let dimY = cy - r - 16
            var dim = Path()
            dim.move(to: CGPoint(x: leftC.x - r, y: dimY))
            dim.addLine(to: CGPoint(x: leftC.x + r, y: dimY))
            ctx.stroke(dim, with: .color(dimColor), lineWidth: 1)
            ctx.draw(Text(fmt(blank.odO)).font(.system(.footnote, design: .monospaced)).foregroundStyle(dimColor),
                     at: CGPoint(x: leftC.x, y: dimY - 10))

            // ID dimension on the ring
            ctx.draw(Text("Ø \(fmt(blank.idB))").font(.system(.footnote, design: .monospaced)).foregroundStyle(dimColor),
                     at: CGPoint(x: rightC.x, y: cy + r + 16))

            // Thickness callout
            ctx.draw(Text("t = \(fmt(blank.thk))").font(.system(.footnote, design: .monospaced)).foregroundStyle(dimColor),
                     at: CGPoint(x: size.width / 2, y: size.height - 8))
        }
        .accessibilityLabel("Figure-8 blank drawing. Tap to toggle fractions.")
    }
}
