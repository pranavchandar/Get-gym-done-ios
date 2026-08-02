import Foundation

// Port of `get-gym-done-web/src/domain/units.ts`.
//
// Weights are stored in kilograms everywhere and converted only for display. The
// conversion itself is exact; rounding is applied deliberately at the presentation
// boundary (see DEFECT #19 below).

public let kgPerLb: Double = 0.45359237

/// Lenient parse used when importing a backup — anything that isn't "lbs" is kg.
public func parseUnit(_ raw: String?) -> Units {
    (raw ?? "").lowercased() == "lbs" ? .lbs : .kg
}

/// Exact kg -> display-unit conversion. Deliberately unrounded.
public func kgToDisplay(_ kg: Double, _ unit: Units) -> Double {
    unit == .lbs ? kg / kgPerLb : kg
}

/// Exact display-unit -> kg conversion. Deliberately unrounded.
public func displayToKg(_ value: Double, _ unit: Units) -> Double {
    unit == .lbs ? value * kgPerLb : value
}

/// The stepper increment in display units: 2.5 kg or 5 lb, matching gym plate maths.
public func displayStep(_ unit: Units) -> Double {
    unit == .lbs ? 5.0 : 2.5
}

/// The progressive-overload increment expressed in kg (2.5 kg, or 5 lb worth of kg).
public func incrementKgFor(_ unit: Units) -> Double {
    displayToKg(displayStep(unit), unit)
}

/// Round to two decimals — the web's generic `roundDisplay`.
public func roundDisplay(_ value: Double) -> Double {
    (value * 100).rounded() / 100
}

// MARK: - DEFECT #19

/// Snap a display value to a sensible precision for its unit.
///
/// DEFECT #19: the web app converts exactly and then shows the raw result, so lbs mode
/// leaks values like `44.09 lbs`, and stepping from there yields 46.59, 49.09 … Kilograms
/// don't have this problem because they are the storage unit and land on clean 2.5
/// boundaries. Fixed here by snapping lbs to the nearest 0.5 for DISPLAY only —
/// `kgToDisplay`/`displayToKg` stay mathematically exact so stored data is unaffected.
public func roundedDisplay(_ value: Double, for unit: Units) -> Double {
    switch unit {
    case .lbs: return (value * 2).rounded() / 2
    case .kg: return roundDisplay(value)
    }
}

/// The value a stepper should show when it starts from `kg`, snapped for the unit.
public func displayValue(fromKg kg: Double, unit: Units) -> Double {
    roundedDisplay(kgToDisplay(kg, unit), for: unit)
}

/// Format a stored kg weight for display, trimming trailing zeros ("62.5", "60").
public func formatWeight(_ kg: Double, _ unit: Units) -> String {
    formatNumber(roundedDisplay(kgToDisplay(kg, unit), for: unit))
}

/// Trailing-zero-trimming number formatting, matching JS `String(parseFloat(v))`.
public func formatNumber(_ value: Double) -> String {
    if value == value.rounded() && abs(value) < 1e15 {
        return String(Int(value.rounded()))
    }
    var s = String(format: "%.2f", value)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}

public func unitLabel(_ unit: Units) -> String {
    unit.rawValue
}
