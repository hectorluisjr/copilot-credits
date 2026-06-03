import Foundation

/// Small display-formatting helpers shared by the views.
enum Format {
    /// Whole credits — no decimals or grouping separators (e.g. `7500`, `278`).
    static func compact(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    /// Formats a 0...1 ratio as a percentage.
    static func percent(_ ratio: Double) -> String {
        String(format: "%.1f%%", ratio * 100)
    }

    /// Formats an already-computed percentage value, with precision that adapts
    /// to small fractions (e.g. `0.024` -> "0.02%", `3.6` -> "3.6%").
    static func percentValue(_ percent: Double) -> String {
        if percent <= 0 { return "0%" }
        if percent < 1 { return String(format: "%.2f%%", percent) }
        if percent < 10 { return String(format: "%.1f%%", percent) }
        return String(format: "%.0f%%", percent)
    }

    /// Relative description like "2 minutes ago".
    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .numeric))
    }

    /// Medium date like "Jun 30, 2026".
    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// Short month/day like "Jun 2".
    static func dayShort(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}
