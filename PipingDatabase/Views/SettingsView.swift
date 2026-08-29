import SwiftUI

struct SettingsView: View {
    @AppStorage("unitSystem") private var unitRaw = UnitSystem.imperial.rawValue
    @AppStorage("nominalStyle") private var nominalRaw = NominalStyle.nps.rawValue
    @AppStorage("fractionDisplay") private var showFractions = false
    @AppStorage("volumeUnit") private var volumeRaw = VolumeUnit.cubicFeet.rawValue

    var body: some View {
        Form {
            Section("Units") {
                Picker("Unit system", selection: $unitRaw) {
                    Text("inch").tag(UnitSystem.imperial.rawValue)
                    Text("mm").tag(UnitSystem.metric.rawValue)
                }
                .pickerStyle(.segmented)

                Picker("Nominal Ø", selection: $nominalRaw) {
                    Text("NPS").tag(NominalStyle.nps.rawValue)
                    Text("DN").tag(NominalStyle.dn.rawValue)
                }
                .pickerStyle(.segmented)

                Picker("Volume", selection: $volumeRaw) {
                    ForEach(VolumeUnit.allCases) { Text($0.label).tag($0.rawValue) }
                }
            }

            Section {
                Toggle("Show fractions", isOn: $showFractions)
            } footer: {
                Text("Imperial dimensions display as trade fractions to the nearest ¹⁄₁₆\". You can also tap any drawing to toggle this.")
            }

            Section {
                LabeledContent("Pipe", value: "ASME B36.10M · B36.19M")
                LabeledContent("Fittings", value: "ASME B16.9 · B16.11")
                LabeledContent("Flanges", value: "ASME B16.5")
                LabeledContent("Valves", value: "ASME B16.10")
                LabeledContent("Branch connections", value: "MSS SP-97")
                LabeledContent("Line blanks", value: "ASME B16.48")
            } header: {
                Text("Data sources")
            } footer: {
                Text("Dimensional data compiled from published manufacturer catalogs reprinting the governing standards. Always verify critical dimensions against the current standard edition.")
            }
        }
        .navigationTitle("Settings")
    }
}
