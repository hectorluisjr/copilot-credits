import Foundation

/// A monthly billing period: the half-open interval `[start, reset)`.
struct BillingPeriod: Equatable, Sendable {
    let start: Date   // inclusive — local midnight of the anchor day
    let reset: Date   // exclusive end / next reset — local midnight
}

/// Computes the current monthly allowance period for a reset that recurs on a
/// given day of month (clamped to each month's length — e.g. day 31 becomes
/// Feb 28). Validated against the Copilot footer ("Resets in 28 days on
/// Jun 30, 2026" => period May 30 – Jun 30).
enum BillingPeriodCalculator {
    /// The allowance resets on the 1st of each month (calendar month) for this
    /// account — confirmed against the GitHub admin panel.
    static let monthlyResetDay = 1

    static func current(resetDay: Int, now: Date, calendar: Calendar = .current) -> BillingPeriod {
        let day = max(1, min(resetDay, 31))
        let startOfToday = calendar.startOfDay(for: now)

        // Midnight of the anchor day in the given month, clamped to month length.
        func anchor(year: Int, month: Int) -> Date {
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            let firstOfMonth = calendar.date(from: comps)!
            let range = calendar.range(of: .day, in: .month, for: firstOfMonth)!
            comps.day = min(day, range.count)
            return calendar.startOfDay(for: calendar.date(from: comps)!)
        }

        let nowComps = calendar.dateComponents([.year, .month], from: now)
        let thisAnchor = anchor(year: nowComps.year!, month: nowComps.month!)

        if startOfToday >= thisAnchor {
            // Period started this month; resets next month.
            let next = calendar.date(byAdding: .month, value: 1, to: thisAnchor)!
            let c = calendar.dateComponents([.year, .month], from: next)
            return BillingPeriod(start: thisAnchor, reset: anchor(year: c.year!, month: c.month!))
        } else {
            // Period started last month; resets on this month's anchor.
            let prev = calendar.date(byAdding: .month, value: -1, to: thisAnchor)!
            let c = calendar.dateComponents([.year, .month], from: prev)
            return BillingPeriod(start: anchor(year: c.year!, month: c.month!), reset: thisAnchor)
        }
    }

    /// Whole days from `now` until `date` (never negative).
    static func daysUntil(_ date: Date, from now: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: now)
        let b = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
    }
}
