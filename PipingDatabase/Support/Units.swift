import Foundation

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

enum Format {
    /// Length stored in inches, shown per unit system.
    static func length(_ inches: Double, unit: UnitSystem, decimals: Int = 3) -> String {
        switch unit {
        case .imperial: return String(format: "%.\(decimals)f in", inches)
        case .metric: return String(format: "%.2f mm", inches * 25.4)
        }
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
