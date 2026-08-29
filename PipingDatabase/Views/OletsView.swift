import SwiftUI

struct OletsView: View {
    @AppStorage("unitSystem") private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage("fractionDisplay") private var showFractions = false

    @State private var selectedType = "weldolet"
    @State private var selectedClass = "STD"
    @State private var selectedBranch = "1/2"
    @State private var selectedRunKey = ""

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .imperial }
    private var file: OletsFile? { ReferenceStore.shared.olets }
    private var olets: [OletsFile.Olet] { file?.olets ?? [] }

    static let typeLabels: [(String, String)] = [
        ("weldolet", "Weldolet"), ("sockolet", "Sockolet"), ("thredolet", "Thredolet"),
    ]

    private var classes: [String] {
        let order = ["STD", "XS", "XXS", "3000", "6000", "9000"]
        let present = Set(olets.filter { $0.type == selectedType }.map(\.class))
        return order.filter(present.contains)
    }

    private var branches: [String] {
        NPS.sorted(olets.filter { $0.type == selectedType && $0.class == selectedClass }.map(\.branch))
    }

    private var runRows: [OletsFile.Olet] {
        olets.filter { $0.type == selectedType && $0.class == selectedClass && $0.branch == selectedBranch }
            .sorted { NPS.value($0.runFrom ?? "") < NPS.value($1.runFrom ?? "") }
    }

    private var selection: OletsFile.Olet? {
        runRows.first { $0.id == selectedRunKey } ?? runRows.first
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let o = selection {
                        OletDrawingView(olet: o, unit: unit, fractions: showFractions)
                            .frame(height: 190)
                            .contentShape(Rectangle())
                            .onTapGesture { showFractions.toggle() }
                        runCard(for: o)
                        dimsCard(for: o)
                    } else {
                        ContentUnavailableView("No data", systemImage: "circle.slash")
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal)
            }
            pickers
        }
        .navigationTitle("Branch Connections")
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
        .onChange(of: selectedBranch) { selectedRunKey = runRows.first?.id ?? "" }
    }

    private func reconcile() {
        if !classes.contains(selectedClass), let first = classes.first { selectedClass = first }
        if !branches.contains(selectedBranch), let first = branches.first { selectedBranch = first }
        selectedRunKey = runRows.first?.id ?? ""
    }

    private func fmt(_ inches: Double) -> String {
        Format.length(inches, unit: unit, fractions: showFractions)
    }

    private func runCard(for o: OletsFile.Olet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fits run pipe").font(.caption2).foregroundStyle(.secondary)
            if runRows.count > 1 {
                Picker("Run range", selection: $selectedRunKey) {
                    ForEach(runRows) { row in
                        Text(row.runRangeText).tag(row.id)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Text(o.runRangeText).font(.callout.monospacedDigit()).bold()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dimsCard(for o: OletsFile.Olet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(o.dims.keys.sorted(), id: \.self) { key in
                HStack(alignment: .firstTextBaseline) {
                    Text(key).font(.callout.monospaced()).bold().frame(width: 34, alignment: .leading)
                    Text(file?.legend[key] ?? "").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(fmt(o.dims[key] ?? 0)).font(.callout.monospacedDigit()).bold()
                }
            }
            if let w = o.weight {
                HStack {
                    Text("Weight").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f lb", w)).font(.callout.monospacedDigit()).bold()
                }
            }
            Divider()
            Text(file?.standard ?? "MSS SP-97").font(.caption2).foregroundStyle(.secondary)
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
            .frame(width: 90)

            Picker("Branch", selection: $selectedBranch) {
                ForEach(branches, id: \.self) { Text("\($0)\"").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 100)
        }
        .frame(height: 130)
        .frame(maxWidth: 600)
        .background(.bar)
    }
}

/// Olet body seated on a run-pipe arc, height callout — like the recon screenshot.
struct OletDrawingView: View {
    let olet: OletsFile.Olet
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
            let cx = size.width / 2
            let baseY = size.height * 0.78
            let runR = size.width * 0.42

            // Run pipe arc
            var runPath = Path()
            runPath.addArc(center: CGPoint(x: cx, y: baseY + runR * 0.62),
                           radius: runR, startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
            ctx.stroke(runPath, with: .color(line), lineWidth: 1.5)

            // Olet body: tapered hex-ish profile on top
            let bw = size.width * 0.24
            let topW = bw * 0.72
            let topY = size.height * 0.18
            let seatY = baseY - runR * 0.16
            var body = Path()
            body.move(to: CGPoint(x: cx - bw / 2, y: seatY))
            body.addLine(to: CGPoint(x: cx - bw / 2, y: topY + 14))
            body.addLine(to: CGPoint(x: cx - topW / 2, y: topY))
            body.addLine(to: CGPoint(x: cx + topW / 2, y: topY))
            body.addLine(to: CGPoint(x: cx + bw / 2, y: topY + 14))
            body.addLine(to: CGPoint(x: cx + bw / 2, y: seatY))
            ctx.stroke(body, with: .color(line), lineWidth: 1.5)

            // Centerline
            var center = Path()
            center.move(to: CGPoint(x: cx, y: topY - 10))
            center.addLine(to: CGPoint(x: cx, y: baseY + 10))
            ctx.stroke(center, with: .color(Color.cyan.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 0.8, dash: [10, 3, 2, 3]))

            // Height dimension (principal dim, usually the olet height)
            if let (key, value) = olet.dims.sorted(by: { $0.key < $1.key }).first {
                let x = cx + bw / 2 + 26
                var d = Path()
                d.move(to: CGPoint(x: x, y: topY))
                d.addLine(to: CGPoint(x: x, y: seatY))
                ctx.stroke(d, with: .color(dim), lineWidth: 1)
                ctx.draw(Text("\(key) \(fmt(value))")
                    .font(.system(.footnote, design: .monospaced)).foregroundStyle(dim),
                         at: CGPoint(x: x, y: topY - 12))
            }
        }
        .accessibilityLabel("Branch connection outline on run pipe. Tap to toggle fractions.")
    }
}
