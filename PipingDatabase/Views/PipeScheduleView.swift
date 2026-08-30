import SwiftUI
import SwiftData

struct PipeScheduleView: View {
    @Query(sort: \NominalSize.sortValue) private var sizes: [NominalSize]
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.modelContext) private var context

    init(preselect: [String: String] = [:]) {
        _selectedNPS = State(initialValue: preselect["nps"] ?? "1/2")
        _selectedDesignation = State(initialValue: preselect["s"] ?? "40")
    }

    @AppStorage(PrefKey.unitSystem) private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage(PrefKey.nominalStyle) private var nominalRaw = NominalStyle.nps.rawValue
    @AppStorage(PrefKey.fractionDisplay) private var showFractions = false
    @AppStorage(PrefKey.volumeUnit) private var volumeRaw = VolumeUnit.cubicFeet.rawValue

    @State private var selectedNPS: String
    @State private var selectedDesignation: String
    @State private var lengthFt = 1.0
    @State private var isFavorite = false
    @State private var showCompare = false
    @State private var showInfo = false
    @FocusState private var lengthFocused: Bool

    private var payload: String { "nps=\(selectedNPS)&s=\(selectedDesignation)" }
    private var lookupTitle: String { "\(selectedNPS)\" Sch \(selectedDesignation) Pipe" }
    private var lookupDetail: String {
        guard let e = entry else { return "" }
        return "OD \(String(format: "%.3f", e.odInches)) · Wall \(String(format: "%.3f", e.wallInches))"
    }

    private var unit: UnitSystem { UnitSystem(rawValue: unitRaw) ?? .imperial }
    private var nominalStyle: NominalStyle { NominalStyle(rawValue: nominalRaw) ?? .nps }
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeRaw) ?? .cubicFeet }

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
                if let entry {
                    if hSize == .regular {
                        HStack(alignment: .top, spacing: 24) {
                            drawing(for: entry)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 300)
                            VStack(spacing: 16) {
                                dataGrid(for: entry)
                                calculator(for: entry)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 16) {
                            drawing(for: entry)
                                .frame(height: 230)
                                .padding(.top, 8)
                            dataGrid(for: entry)
                            calculator(for: entry)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    ContentUnavailableView("No data", systemImage: "circle.slash")
                }
            }
            .scrollDismissesKeyboard(.immediately)
            pickers
        }
        .navigationTitle("Pipe Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    LookupStore.toggleFavorite(context, moduleID: "pipe", payload: payload,
                                               title: lookupTitle, detail: lookupDetail)
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
                .accessibilityLabel(isFavorite ? "Remove favorite" : "Add favorite")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Nominal size", selection: $nominalRaw) {
                        Text("NPS (inches)").tag(NominalStyle.nps.rawValue)
                        Text("DN (metric)").tag(NominalStyle.dn.rawValue)
                    }
                    Toggle("Fractions", isOn: $showFractions)
                    Divider()
                    Button("Compare schedules", systemImage: "rectangle.split.2x1") {
                        showCompare = true
                    }
                    if let entry {
                        ShareLink(item: datasheet(for: entry)) {
                            Label("Share datasheet", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("About this data", systemImage: "info.circle") { showInfo = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(unit.toggleLabel) {
                    unitRaw = (unit == .imperial ? UnitSystem.metric : .imperial).rawValue
                }
                .font(.headline)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { lengthFocused = false }
            }
        }
        .onChange(of: selectedNPS) {
            if !designations.contains(selectedDesignation), let first = designations.first {
                selectedDesignation = first
            }
        }
        .sheet(isPresented: $showCompare) {
            if let size = selectedSize {
                PipeCompareSheet(size: size, baseline: selectedDesignation, unit: unit)
            }
        }
        .sheet(isPresented: $showInfo) {
            ModuleInfoSheet(
                title: "Pipe Schedule",
                standard: "ASME B36.10M (carbon) · ASME B36.19M (stainless)",
                notes: "Dimensions and nominal walls per the governing standards. Weights are computed with the B36.10M plain-end formula 10.69 (D−t) t and match the published weight columns within rounding. Water-filled weight assumes fresh water at 60 °F."
            )
        }
        .task(id: payload) {
            isFavorite = LookupStore.isFavorite(context, moduleID: "pipe", payload: payload)
            // Debounce so wheel scrolling doesn't spam recents.
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, entry != nil else { return }
            LookupStore.recordRecent(context, moduleID: "pipe", payload: payload,
                                     title: lookupTitle, detail: lookupDetail)
        }
    }

    private func drawing(for entry: PipeScheduleEntry) -> some View {
        PipeCrossSectionView(entry: entry, unit: unit, fractions: showFractions)
            .contentShape(Rectangle())
            .onTapGesture { showFractions.toggle() }
            .accessibilityLabel("Pipe cross section. Tap to toggle fraction display.")
    }

    private func fmtLength(_ inches: Double) -> String {
        Format.length(inches, unit: unit, fractions: showFractions)
    }

    private func datasheet(for e: PipeScheduleEntry) -> String {
        """
        \(lookupTitle)
        OD \(Format.length(e.odInches, unit: unit)) · ID \(Format.length(e.idInches, unit: unit)) · Wall \(Format.length(e.wallInches, unit: unit))
        Weight \(Format.linearWeight(e.weightLbPerFt, unit: unit)) · Water-filled \(Format.linearWeight(e.waterFilledWeightLbPerFt, unit: unit))
        Source: \(e.standard) — PipeBase \(AppInfo.version)
        """
    }

    private func dataGrid(for entry: PipeScheduleEntry) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                labeled("OD", fmtLength(entry.odInches))
                labeled("Weight", Format.linearWeight(entry.weightLbPerFt, unit: unit))
            }
            GridRow {
                labeled("ID", fmtLength(entry.idInches))
                labeled("W. filled", Format.linearWeight(entry.waterFilledWeightLbPerFt, unit: unit))
            }
            GridRow {
                labeled("Wall", fmtLength(entry.wallInches))
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
                    .focused($lengthFocused)
                Text(unit == .imperial ? "ft" : "m")
                Spacer()
            }
            let ft = unit == .imperial ? lengthFt : lengthFt * 3.28084
            let volume = volumeUnit.convert(cuFt: entry.internalVolumeCuFt(lengthFt: ft))
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    labeled("Ext. SA", Format.area(entry.externalSurfaceSqFt(lengthFt: ft), unit: unit))
                    labeled("Int. SA", Format.area(entry.internalSurfaceSqFt(lengthFt: ft), unit: unit))
                }
                GridRow {
                    labeled("Total SA",
                            Format.area(entry.externalSurfaceSqFt(lengthFt: ft) + entry.internalSurfaceSqFt(lengthFt: ft),
                                        unit: unit))
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        labeled("Volume", String(format: "%.\(volumeUnit.formatDecimals)f", volume))
                        Picker("Volume unit", selection: $volumeRaw) {
                            ForEach(VolumeUnit.allCases) { u in
                                Text(u.label).tag(u.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
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
        .frame(maxWidth: 600)
        .background(.bar)
    }
}
