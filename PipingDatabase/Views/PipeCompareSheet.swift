import SwiftUI

/// Side-by-side schedule comparison for one pipe size, with deltas.
struct PipeCompareSheet: View {
    let size: NominalSize
    let baseline: String
    let unit: UnitSystem
    @State private var other: String = ""
    @Environment(\.dismiss) private var dismiss

    private var designations: [String] {
        size.entries.map(\.designation)
            .sorted { ScheduleOrder.index(of: $0) < ScheduleOrder.index(of: $1) }
    }

    private func entry(_ d: String) -> PipeScheduleEntry? {
        size.entries.first { $0.designation == d }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Compare with", selection: $other) {
                    ForEach(designations.filter { $0 != baseline }, id: \.self) {
                        Text("Sch \($0)").tag($0)
                    }
                }
                .pickerStyle(.menu)

                if let a = entry(baseline), let b = entry(other) {
                    Section("\(size.nps)\" — Sch \(baseline) vs Sch \(other)") {
                        row("Wall", a.wallInches, b.wallInches)
                        row("ID", a.idInches, b.idInches)
                        row("Weight", a.weightLbPerFt, b.weightLbPerFt, isWeight: true)
                        row("W. filled", a.waterFilledWeightLbPerFt, b.waterFilledWeightLbPerFt, isWeight: true)
                    }
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear {
                if other.isEmpty {
                    other = designations.first { $0 != baseline } ?? baseline
                }
            }
        }
    }

    private func row(_ label: String, _ a: Double, _ b: Double, isWeight: Bool = false) -> some View {
        let fmtVal: (Double) -> String = isWeight
            ? { Format.linearWeight($0, unit: self.unit) }
            : { Format.length($0, unit: self.unit) }
        let delta = b - a
        return VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack {
                Text(fmtVal(a)).font(.callout.monospacedDigit()).bold()
                Spacer()
                Text(fmtVal(b)).font(.callout.monospacedDigit()).bold()
                Text(delta >= 0 ? "▲" : "▼")
                    .font(.caption2)
                    .foregroundStyle(delta >= 0 ? .orange : .teal)
            }
        }
    }
}

/// Per-module provenance sheet — the ⓘ of the original app, with citations.
struct ModuleInfoSheet: View {
    let title: String
    let standard: String
    let notes: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Governing standard") { Text(standard).font(.callout) }
                Section("Notes") { Text(notes).font(.callout) }
                Section {
                    Text("Data compiled from published manufacturer catalogs that reprint the governing standards, cross-checked against independent sources and locked by automated golden-value tests. Always verify critical dimensions against the current standard edition before fabrication.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
