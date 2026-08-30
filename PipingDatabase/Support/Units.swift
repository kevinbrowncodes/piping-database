import Foundation

/// Single source of truth for UserDefaults preference keys — used by every
/// @AppStorage site and by the debug-only UITEST_RESET hook. Deliberately
/// excludes Seeder.versionKey (wiping it would force a full re-seed).
enum PrefKey {
    static let unitSystem = "unitSystem"
    static let nominalStyle = "nominalStyle"
    static let fractionDisplay = "fractionDisplay"
    static let volumeUnit = "volumeUnit"
    static let moduleOrder = "moduleOrder"
    static let all = [unitSystem, nominalStyle, fractionDisplay, volumeUnit, moduleOrder]
}

enum AppInfo {
    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }
}

enum UnitSystem: String, CaseIterable {
    case imperial
    case metric

    var toggleLabel: String { self == .imperial ? "in" : "mm" }
}

enum NominalStyle: String, CaseIterable {
    case nps
    case dn
}

/// Display order for schedule designations across the picker.
enum ScheduleOrder {
    static let order: [String] = [
        "5", "5S", "10", "10S", "20", "30",
        "STD", "40", "40S", "60", "XS", "80", "80S",
        "100", "120", "140", "160", "XXS",
    ]

    static func index(of designation: String) -> Int {
        order.firstIndex(of: designation) ?? order.count
    }
}

enum VolumeUnit: String, CaseIterable, Identifiable {
    case cubicFeet, gallons, liters, cubicMeters
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cubicFeet: return "ft³"
        case .gallons: return "gal"
        case .liters: return "L"
        case .cubicMeters: return "m³"
        }
    }

    func convert(cuFt: Double) -> Double {
        switch self {
        case .cubicFeet: return cuFt
        case .gallons: return cuFt * 7.48052
        case .liters: return cuFt * 28.3168
        case .cubicMeters: return cuFt * 0.0283168
        }
    }

    var formatDecimals: Int {
        switch self {
        case .cubicFeet, .cubicMeters: return 6
        case .gallons, .liters: return 4
        }
    }
}

enum Format {
    /// Length stored in inches, shown per unit system.
    static func length(_ inches: Double, unit: UnitSystem, decimals: Int = 3) -> String {
        switch unit {
        case .imperial: return String(format: "%.\(decimals)f in", inches)
        case .metric: return String(format: "%.2f mm", inches * 25.4)
        }
    }

    /// Trade-fraction rendering to the nearest 1/16" (reduced), matching the
    /// reference app's tap-any-dimension feature. Values that don't land on
    /// a sixteenth are prefixed with ≈.
    static func fractionalInches(_ inches: Double) -> String {
        let sixteenths = (inches * 16).rounded()
        let exact = abs(inches * 16 - sixteenths) < 0.032 // within ~0.002"
        let whole = Int(sixteenths) / 16
        var num = Int(sixteenths) % 16
        var den = 16
        while num != 0 && num % 2 == 0 { num /= 2; den /= 2 }

        var body: String
        if num == 0 {
            body = "\(whole)"
        } else if whole == 0 {
            body = "\(num)/\(den)"
        } else {
            body = "\(whole) \(num)/\(den)"
        }
        return (exact ? "" : "≈") + body + "\""
    }

    /// Length honoring the user's fraction preference (imperial only).
    static func length(_ inches: Double, unit: UnitSystem, fractions: Bool) -> String {
        guard unit == .imperial, fractions else { return length(inches, unit: unit) }
        return fractionalInches(inches)
    }

    static func linearWeight(_ lbPerFt: Double, unit: UnitSystem) -> String {
        switch unit {
        case .imperial: return String(format: "%.2f lb/ft", lbPerFt)
        case .metric: return String(format: "%.2f kg/m", lbPerFt * 1.48816)
        }
    }

    static func area(_ sqFt: Double, unit: UnitSystem) -> String {
        switch unit {
        case .imperial: return String(format: "%.2f ft²", sqFt)
        case .metric: return String(format: "%.3f m²", sqFt * 0.0929030)
        }
    }

    static func volume(_ cuFt: Double, unit: UnitSystem) -> String {
        switch unit {
        case .imperial: return String(format: "%.6f ft³", cuFt)
        case .metric: return String(format: "%.4f L", cuFt * 28.3168)
        }
    }
}
