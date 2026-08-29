import Foundation

/// Feet-inch-sixteenths construction calculator engine.
/// All values are inches internally; ops are plain arithmetic on inches
/// (matching how trade calculators behave), display formats per mode.
struct TradeCalcEngine {
    enum Op { case add, sub, mul, div }
    enum DisplayMode: CaseIterable { case feetInches, decimalInches, millimeters }

    private(set) var accumulator: Double?
    private(set) var pendingOp: Op?
    private(set) var memory: Double = 0
    private(set) var mode: DisplayMode = .feetInches

    // Current entry being typed
    private var feetPart: Double?
    private var digits = ""
    private var sixteenths = 0
    private var typedSinceResult = false
    private var result: Double?

    /// Current entry in inches.
    private var entryInches: Double {
        (feetPart ?? 0) * 12 + (Double(digits) ?? 0) + Double(sixteenths) / 16
    }

    private var hasEntry: Bool {
        feetPart != nil || !digits.isEmpty || sixteenths != 0
    }

    /// Value currently on the display, inches.
    var displayInches: Double {
        if hasEntry { return entryInches }
        if let r = result { return r }
        return accumulator ?? 0
    }

    // MARK: Keys

    mutating func digit(_ d: Int) {
        precondition((0...9).contains(d))
        if result != nil && pendingOp == nil { clearAll() }
        if digits.count < 9 { digits += String(d) }
    }

    mutating func feet() {
        guard feetPart == nil else { return }
        feetPart = Double(digits) ?? 0
        digits = ""
    }

    /// Add a fraction in sixteenths (e.g. 1/2 → 8).
    mutating func fraction(sixteenths n: Int) {
        if result != nil && pendingOp == nil { clearAll() }
        sixteenths = n
    }

    mutating func backspace() {
        if sixteenths != 0 { sixteenths = 0 } else if !digits.isEmpty { digits.removeLast() } else { feetPart = nil }
    }

    mutating func plusMinus() {
        if hasEntry {
            if let f = feetPart { feetPart = -f } else if let v = Double(digits) { digits = String(-v) }
        } else if let r = result {
            result = -r
        } else if let a = accumulator {
            accumulator = -a
        }
    }

    mutating func op(_ o: Op) {
        commitPending()
        pendingOp = o
    }

    mutating func equals() {
        commitPending()
        result = accumulator
        accumulator = nil
        pendingOp = nil
    }

    private mutating func commitPending() {
        let operand = hasEntry ? entryInches : (result ?? accumulator ?? 0)
        if let a = accumulator, let o = pendingOp, hasEntry {
            switch o {
            case .add: accumulator = a + operand
            case .sub: accumulator = a - operand
            case .mul: accumulator = a * operand
            case .div: accumulator = operand == 0 ? 0 : a / operand
            }
        } else if hasEntry || accumulator == nil {
            accumulator = operand
        }
        result = nil
        clearEntry()
    }

    mutating func allClear() { self = TradeCalcEngine(memory: memory, mode: mode) }

    private mutating func clearAll() {
        accumulator = nil
        pendingOp = nil
        result = nil
        clearEntry()
    }

    private mutating func clearEntry() {
        feetPart = nil
        digits = ""
        sixteenths = 0
    }

    // MARK: Memory

    mutating func memoryAdd() { memory += displayInches }
    mutating func memorySubtract() { memory -= displayInches }
    mutating func memoryRecall() {
        clearEntry()
        result = memory
        accumulator = nil
    }
    mutating func memoryClear() { memory = 0 }

    mutating func cycleMode() {
        let all = DisplayMode.allCases
        mode = all[(all.firstIndex(of: mode)! + 1) % all.count]
    }

    init() {}
    private init(memory: Double, mode: DisplayMode) {
        self.memory = memory
        self.mode = mode
    }

    // MARK: Formatting

    /// e.g. 63.5 → 5'-3 ½" in feetInches mode.
    var displayText: String {
        Self.format(inches: displayInches, mode: mode)
    }

    static func format(inches: Double, mode: DisplayMode) -> String {
        switch mode {
        case .decimalInches:
            return String(format: "%.3f\"", inches)
        case .millimeters:
            return String(format: "%.1f mm", inches * 25.4)
        case .feetInches:
            let negative = inches < 0
            let total = abs(inches)
            let sixteenths = (total * 16).rounded()
            let wholeInches = Int(sixteenths) / 16
            let ft = wholeInches / 12
            let inch = wholeInches % 12
            var num = Int(sixteenths) % 16
            var den = 16
            while num != 0 && num % 2 == 0 { num /= 2; den /= 2 }
            var s = "\(ft)'-\(inch)"
            if num != 0 { s += " \(num)/\(den)" }
            s += "\""
            return (negative ? "-" : "") + s
        }
    }
}
