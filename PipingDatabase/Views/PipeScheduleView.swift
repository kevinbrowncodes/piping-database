import SwiftUI
import SwiftData

struct PipeScheduleView: View {
    @Query(sort: \NominalSize.sortValue) private var sizes: [NominalSize]

    @AppStorage("unitSystem") private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage("nominalStyle") private var nominalRaw = NominalStyle.nps.rawValue

    @State private var selectedNPS = "1/2"
    @State private var selectedDesignation = "40"
    @State private var lengthFt = 1.0

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .imperial }
    private var nominalStyle: NominalStyle { NominalStyle(rawValue: nominalRaw) ?? .nps }

    private var selectedSize: NominalSize? {
        sizes.first { $0.nps == selectedNPS } ?? sizes.first
    }

    private var designations: [String] {
        guard let size = selectedSize else { return [] }
        return size.entries
            .map(\.designation)
            .sorted { ScheduleOrder.index(of: $0) < ScheduleOrder.index(of: $1) }
    }

    private var entry: PipeScheduleEntry? {
        selectedSize?.entries.first { $0.designation == selectedDesignation }
            ?? selectedSize?.entries.min { ScheduleOrder.index(of: $0.designation) < ScheduleOrder.index(of: $1.designation) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    if let entry {
                        PipeCrossSectionView(entry: entry, unit: unit)
                            .frame(height: 230)
                            .padding(.top, 8)
                        dataGrid(for: entry)
                        calculator(for: entry)
                    } else {
                        ContentUnavailableView("No data", systemImage: "circle.slash")
                    }
                }
                .padding(.horizontal)
            }
            pickers
        }
        .navigationTitle("Pipe Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(unit.toggleLabel) {
                    unitRaw = (unit == .imperial ? UnitSystem.metric : .imperial).rawValue
                }
                .font(.headline)
            }
        }
        .onChange(of: selectedNPS) {
            if !designations.contains(selectedDesignation), let first = designations.first {
                selectedDesignation = first
            }
        }
    }

    private func dataGrid(for entry: PipeScheduleEntry) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                labeled("OD", Format.length(entry.odInches, unit: unit))
                labeled("Weight", Format.linearWeight(entry.weightLbPerFt, unit: unit))
            }
            GridRow {
                labeled("ID", Format.length(entry.idInches, unit: unit))
                labeled("W. filled", Format.linearWeight(entry.waterFilledWeightLbPerFt, unit: unit))
            }
            GridRow {
                labeled("Wall", Format.length(entry.wallInches, unit: unit))
                labeled("Source", entry.standard)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func calculator(for entry: PipeScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Length")
                TextField("Length", value: $lengthFt, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Text(unit == .imperial ? "ft" : "m")
                Spacer()
            }
            let ft = unit == .imperial ? lengthFt : lengthFt * 3.28084
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    labeled("Ext. SA", Format.area(entry.externalSurfaceSqFt(lengthFt: ft), unit: unit))
                    labeled("Int. SA", Format.area(entry.internalSurfaceSqFt(lengthFt: ft), unit: unit))
                }
                GridRow {
                    labeled("Volume", Format.volume(entry.internalVolumeCuFt(lengthFt: ft), unit: unit))
                    labeled("Total SA",
                            Format.area(entry.externalSurfaceSqFt(lengthFt: ft) + entry.internalSurfaceSqFt(lengthFt: ft),
                                        unit: unit))
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
            Picker("Size", selection: $selectedNPS) {
                ForEach(sizes) { size in
                    Text(nominalStyle == .nps ? "\(size.nps)\"" : "DN \(size.dn)")
                        .tag(size.nps)
                }
            }
            .pickerStyle(.wheel)

            Picker("Schedule", selection: $selectedDesignation) {
                ForEach(designations, id: \.self) { d in
                    Text("Sch \(d)").tag(d)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(height: 130)
        .background(.bar)
    }
}
