import Foundation

/// Single source of truth for the telemetry -> credits conversion.
///
/// Copilot footer credit values match the raw `copilotUsageNanoAiu` field
/// scaled by 1e9. Keeping the constant here means a future schema/unit change
/// is a one-line edit (see the "Operational Caveat" in the plan doc).
enum CreditConstants {
    static let nanoAiuToCreditsScale: Double = 1_000_000_000.0
}

/// Converts a raw `copilotUsageNanoAiu` value into visible credits.
func creditsFromNanoAiu(_ nanoAiu: Double) -> Double {
    nanoAiu / CreditConstants.nanoAiuToCreditsScale
}
