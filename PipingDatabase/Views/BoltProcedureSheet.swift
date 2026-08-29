import SwiftUI

/// The 7-step flange bolt-up procedure with a star-pattern sequence diagram
/// drawn for the actual bolt count of the selected flange.
struct BoltProcedureSheet: View {
    let numHoles: Int
    let torqueFile: BoltTorqueFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BoltPatternDiagram(numHoles: numHoles)
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)

                    ForEach(Array(torqueFile.procedure.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.callout.bold().monospacedDigit())
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(.tint.opacity(0.15)))
                            Text(step).font(.callout)
                        }
                    }

                    Text(torqueFile.source)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Bolt-Up Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Numbered star-sequence bolt pattern for any multiple-of-4 bolt count.
struct BoltPatternDiagram: View {
    let numHoles: Int

    /// Cross-pattern tightening sequence (1 at top, 2 opposite, then quarters).
    private var sequence: [Int] {
        let n = max(numHoles, 4)
        var order: [Int] = []
        var remaining = Set(0..<n)
        var current = 0
        while !remaining.isEmpty {
            if remaining.contains(current) {
                order.append(current)
                remaining.remove(current)
            }
            let opposite = (current + n / 2) % n
            if remaining.contains(opposite) {
                order.append(opposite)
                remaining.remove(opposite)
            }
            current = remaining.min() ?? 0
        }
        var position = [Int](repeating: 0, count: n)
        for (seq, pos) in order.enumerated() { position[pos] = seq + 1 }
        return position
    }

    var body: some View {
        Canvas { ctx, size in
            let n = max(numHoles, 4)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) * 0.38
            let holeR: CGFloat = n > 16 ? 9 : 13

            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                       with: .color(.secondary.opacity(0.4)), lineWidth: 1)

            let seq = sequence
            for i in 0..<n {
                let angle = Double(i) / Double(n) * 2 * .pi - .pi / 2
                let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - holeR, y: p.y - holeR, width: 2 * holeR, height: 2 * holeR)),
                         with: .color(.accentColor.opacity(0.15)))
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - holeR, y: p.y - holeR, width: 2 * holeR, height: 2 * holeR)),
                           with: .color(.accentColor), lineWidth: 1)
                ctx.draw(Text("\(seq[i])").font(.system(size: n > 16 ? 9 : 12, weight: .bold).monospacedDigit()),
                         at: p)
            }
            ctx.draw(Text("\(n)-bolt sequence").font(.caption).foregroundStyle(.secondary),
                     at: center)
        }
        .accessibilityLabel("Star tightening sequence for \(numHoles) bolts")
    }
}

/// Full pressure–temperature table for one class.
struct PTTableSheet: View {
    let cls: String
    let file: PTRatingsFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(file.temperaturesF.enumerated()), id: \.offset) { i, temp in
                        HStack {
                            Text(i == 0 ? "−20 to 100 °F" : "\(temp) °F")
                            Spacer()
                            Text("\(file.classes[cls]?[i] ?? 0) psig")
                                .font(.body.monospacedDigit()).bold()
                        }
                    }
                } header: {
                    Text("Class \(cls) · Material group \(file.materialGroup)")
                } footer: {
                    Text("\(file.materials). \(file.note) Source: \(file.source).")
                }
            }
            .navigationTitle("P-T Ratings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
