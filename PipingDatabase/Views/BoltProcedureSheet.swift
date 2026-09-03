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

/// Star (criss-cross) tightening order for a bolt circle.
///
/// Positions are numbered 0 at the top, clockwise. The legacy star pattern
/// tightens opposite pairs a quarter turn apart: 0°-180°, 90°-270°,
/// 45°-225°, 135°-315°, … — the same words as step 6 of the printed
/// procedure. For 8 bolts that reads 1-5-3-7-2-6-4-8 around the circle.
enum BoltSequence {
    /// Hole positions in tightening order.
    static func order(count n: Int) -> [Int] {
        guard n > 0 else { return [] }
        guard n >= 4, n % 4 == 0 else { return oppositePairs(count: n) }
        let quarter = n / 4
        var order: [Int] = []
        for k in 0..<quarter {
            order += [k, k + n / 2, k + quarter, k + 3 * quarter]
        }
        return order
    }

    /// Sequence number (1-based) shown at each hole position.
    static func numbers(count n: Int) -> [Int] {
        var position = [Int](repeating: 0, count: max(n, 0))
        for (seq, pos) in order(count: n).enumerated() { position[pos] = seq + 1 }
        return position
    }

    /// Bolt counts that are not a multiple of four (none in B16.5/B16.47):
    /// opposite pairs, stepping a quarter turn between pairs.
    private static func oppositePairs(count n: Int) -> [Int] {
        var order: [Int] = []
        var remaining = Set(0..<n)
        var current = 0
        while !remaining.isEmpty {
            for p in [current, (current + n / 2) % n] where remaining.contains(p) {
                order.append(p)
                remaining.remove(p)
            }
            let next = (current + max(n / 4, 1)) % n
            current = remaining.contains(next) ? next : (remaining.min() ?? 0)
        }
        return order
    }
}

/// Numbered star-sequence bolt pattern for any bolt count.
struct BoltPatternDiagram: View {
    let numHoles: Int

    private var sequence: [Int] { BoltSequence.numbers(count: max(numHoles, 4)) }

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
