import SwiftUI

struct FlangesView: View {
    @AppStorage("unitSystem") private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage("fractionDisplay") private var showFractions = false

    @State private var selectedClass = "150"
    @State private var selectedType = "WN"
    @State private var selectedNPS = "2"

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .imperial }
    private var file: FlangesFile? { ReferenceStore.shared.flanges }

    static let typeLabels: [(String, String)] = [
        ("WN", "Weld Neck"), ("SO", "Slip-On"), ("SW", "Socket Weld"),
        ("TH", "Threaded"), ("LJ", "Lap Joint"), ("blind", "Blind"),
    ]

    private var classes: [String] {
        (file?.classes.map(\.class) ?? []).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    private var classData: FlangesFile.FlangeClass? {
        file?.classes.first { $0.class == selectedClass }
    }

    private var sizeOptions: [FlangesFile.FlangeSize] {
        (classData?.sizes ?? []).sorted {
            (NPS.value($0.nps), $0.series ?? "") < (NPS.value($1.nps), $1.series ?? "")
        }
    }

    private var selection: FlangesFile.FlangeSize? {
        sizeOptions.first { $0.key == selectedNPS } ?? sizeOptions.first
    }

    private var availableTypes: [(String, String)] {
        guard let s = selection else { return Self.typeLabels }
        var present = Set<String>()
        if let per = s.perType { present.formUnion(per.keys) }
        if let w = s.weights { present.formUnion(w.keys) }
        let list = Self.typeLabels.filter { present.contains($0.0) }
        return list.isEmpty ? Self.typeLabels : list
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let s = selection {
                        FlangeFaceDrawingView(size: s, unit: unit, fractions: showFractions)
                            .frame(height: 240)
                            .contentShape(Rectangle())
                            .onTapGesture { showFractions.toggle() }
                        drillingCard(for: s)
                        dimsCard(for: s)
                    } else {
                        ContentUnavailableView("No data", systemImage: "circle.slash")
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal)
            }
            pickers
        }
        .navigationTitle("Flanges")
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
            if !sizeOptions.contains(where: { $0.key == selectedNPS }),
               let first = sizeOptions.first {
                selectedNPS = first.key
            }
        }
    }

    private func fmt(_ inches: Double) -> String {
        Format.length(inches, unit: unit, fractions: showFractions)
    }

    private func drillingCard(for s: FlangesFile.FlangeSize) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                labeled("Bolt circle", fmt(s.drilling.boltCircle))
                labeled("No. of bolts", "\(s.drilling.numHoles)")
            }
            GridRow {
                labeled("Bolt Ø", "\(s.drilling.boltDia)\"")
                labeled("Hole Ø", fmt(s.drilling.holeDia))
            }
            let weight = s.weights?[selectedType]
                ?? (["TH", "SO"].contains(selectedType) ? s.weights?["THSO"] : nil)
                ?? (selectedType == "SW" ? s.weights?["THSO"] : nil)
            if let weight {
                GridRow {
                    labeled("Weight (\(selectedType))", String(format: "%.1f lb", weight))
                    labeled("Source", s.series ?? file?.standard ?? "ASME B16.5")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dimsCard(for s: FlangesFile.FlangeSize) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(s.dims.keys.sorted(), id: \.self) { key in
                dimRow(key, s.dims[key] ?? 0)
            }
            if let per = s.perType?[selectedType] {
                Divider()
                Text(Self.typeLabels.first { $0.0 == selectedType }?.1 ?? selectedType)
                    .font(.caption).bold()
                ForEach(per.keys.sorted(), id: \.self) { key in
                    dimRow(key, per[key] ?? 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dimRow(_ key: String, _ value: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).font(.callout.monospaced()).bold().frame(width: 40, alignment: .leading)
            Text(file?.legend[key] ?? "").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(fmt(value)).font(.callout.monospacedDigit()).bold()
        }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).bold()
        }
    }

    private var pickers: some View {
        HStack(spacing: 0) {
            Picker("Type", selection: $selectedType) {
                ForEach(availableTypes, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.wheel)

            Picker("Class", selection: $selectedClass) {
                ForEach(classes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 90)

            Picker("Size", selection: $selectedNPS) {
                ForEach(sizeOptions, id: \.key) { Text("\($0.label)\"").tag($0.key) }
            }
            .pickerStyle(.wheel)
            .frame(width: 110)
        }
        .frame(height: 130)
        .frame(maxWidth: 600)
        .background(.bar)
    }
}

/// Flange face view drawn from real data: OD, bolt circle, actual hole count.
struct FlangeFaceDrawingView: View {
    let size: FlangesFile.FlangeSize
    let unit: UnitSystem
    var fractions: Bool = false

    private func fmt(_ v: Double) -> String {
        if unit == .imperial {
            return fractions ? Format.fractionalInches(v) : String(format: "%.2f", v)
        }
        return String(format: "%.1f", v * 25.4)
    }

    var body: some View {
        Canvas { ctx, canvasSize in
            let line = Color.primary.opacity(0.85)
            let dim = Color.green
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2 + 8)

            guard let od = size.dims["O"] ?? size.dims.values.max() else { return }
            let outerR = min(canvasSize.width, canvasSize.height) * 0.36
            let scale = outerR / (od / 2)
            let bcR = size.drilling.boltCircle / 2 * scale
            let holeR = max(size.drilling.holeDia / 2 * scale, 2)
            let boreR = outerR * 0.42

            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)),
                       with: .color(line), lineWidth: 1.5)
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - boreR, y: center.y - boreR, width: boreR * 2, height: boreR * 2)),
                       with: .color(line), lineWidth: 1)
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - bcR, y: center.y - bcR, width: bcR * 2, height: bcR * 2)),
                       with: .color(Color.cyan.opacity(0.6)),
                       style: StrokeStyle(lineWidth: 0.8, dash: [8, 3, 2, 3]))

            for i in 0..<max(size.drilling.numHoles, 1) {
                let angle = Double(i) / Double(max(size.drilling.numHoles, 1)) * 2 * .pi - .pi / 2
                let p = CGPoint(x: center.x + cos(angle) * bcR, y: center.y + sin(angle) * bcR)
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - holeR, y: p.y - holeR, width: holeR * 2, height: holeR * 2)),
                           with: .color(line), lineWidth: 1)
            }

            // OD dimension
            let dimY = center.y - outerR - 14
            var d = Path()
            d.move(to: CGPoint(x: center.x - outerR, y: dimY))
            d.addLine(to: CGPoint(x: center.x + outerR, y: dimY))
            ctx.stroke(d, with: .color(dim), lineWidth: 1)
            ctx.draw(Text(fmt(od)).font(.system(.footnote, design: .monospaced)).foregroundStyle(dim),
                     at: CGPoint(x: center.x, y: dimY - 10))

            // Bolt circle callout
            ctx.draw(Text("BC \(fmt(size.drilling.boltCircle))")
                .font(.system(.footnote, design: .monospaced)).foregroundStyle(dim),
                     at: CGPoint(x: center.x, y: center.y + outerR + 16))
        }
        .accessibilityLabel("Flange face with bolt pattern. Tap to toggle fractions.")
    }
}
