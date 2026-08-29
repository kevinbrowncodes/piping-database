import SwiftUI

/// Feet-inch-sixteenths trade calculator — a proper tab, not a shake gesture.
struct TradeCalcView: View {
    @State private var engine = TradeCalcEngine()

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            display
            keypad
        }
        .padding()
        .navigationTitle("Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if engine.memory != 0 {
                Text("M \(TradeCalcEngine.format(inches: engine.memory, mode: engine.mode))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(engine.displayText)
                .font(.system(size: 44, weight: .light, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .accessibilityLabel("Calculator display: \(engine.displayText)")
    }

    private let fractionRows: [[(String, Int)]] = [
        [("¹³⁄₁₆", 13), ("⁷⁄₈", 14), ("¹⁵⁄₁₆", 15)],
        [("⁵⁄₈", 10), ("¹¹⁄₁₆", 11), ("³⁄₄", 12)],
        [("⁷⁄₁₆", 7), ("¹⁄₂", 8), ("⁹⁄₁₆", 9)],
        [("¹⁄₄", 4), ("⁵⁄₁₆", 5), ("³⁄₈", 6)],
        [("¹⁄₁₆", 1), ("¹⁄₈", 2), ("³⁄₁₆", 3)],
    ]

    private var keypad: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                key("AC", role: .clear) { engine.allClear() }
                key("mr") { engine.memoryRecall() }
                key("m+") { engine.memoryAdd() }
                key("m−") { engine.memorySubtract() }
                key("mc") { engine.memoryClear() }
            }
            GridRow {
                key("feet", role: .accent) { engine.feet() }
                key("⌫") { engine.backspace() }
                key("+/−") { engine.plusMinus() }
                key("Conv", role: .accent) { engine.cycleMode() }
                key("÷", role: .op) { engine.op(.div) }
            }
            ForEach(0..<5, id: \.self) { row in
                GridRow {
                    let digits = [[8, 9], [6, 7], [4, 5], [2, 3], [0, 1]][row]
                    key("\(digits[0])") { engine.digit(digits[0]) }
                    key("\(digits[1])") { engine.digit(digits[1]) }
                    ForEach(fractionRows[row], id: \.1) { label, n in
                        key(label, role: .fraction) { engine.fraction(sixteenths: n) }
                    }
                }
            }
            GridRow {
                key("×", role: .op) { engine.op(.mul) }
                key("−", role: .op) { engine.op(.sub) }
                key("+", role: .op) { engine.op(.add) }
                key("=", role: .op) { engine.equals() }
                    .gridCellColumns(2)
            }
        }
        .frame(maxWidth: 480)
    }

    private enum KeyRole { case digit, op, accent, clear, fraction }

    private func key(_ label: String, role: KeyRole = .digit, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(role == .fraction ? .body : .title3)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.bordered)
        .tint(tint(for: role))
        .accessibilityLabel(accessibilityName(label))
    }

    private func tint(for role: KeyRole) -> Color? {
        switch role {
        case .digit: return nil
        case .op: return .accentColor
        case .accent: return .teal
        case .clear: return .red
        case .fraction: return .secondary
        }
    }

    private func accessibilityName(_ label: String) -> String {
        switch label {
        case "⌫": return "Delete"
        case "+/−": return "Change sign"
        case "m−": return "Memory subtract"
        default: return label
        }
    }
}
