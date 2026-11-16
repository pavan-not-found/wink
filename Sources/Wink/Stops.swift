import Foundation

/// One position on the duration ruler.
struct DurationStop: Identifiable, Equatable {
    let id: String
    let label: String
    let duration: TimeInterval?     // nil = forever
    let isMorning: Bool

    /// Duration measured from now. Morning is recomputed so it always lands on 8:00.
    func resolvedDuration(now: Date = Date()) -> TimeInterval? {
        isMorning ? Stops.nextMorning(after: now).timeIntervalSince(now) : duration
    }
}

enum Stops {
    static let morningHour = 8

    static func nextMorning(after now: Date = Date()) -> Date {
        let cal = Calendar.current
        var date = cal.date(bySettingHour: morningHour, minute: 0, second: 0, of: now) ?? now
        if date <= now { date = cal.date(byAdding: .day, value: 1, to: date) ?? date }
        return date
    }

    /// The ruler: an uneven scale from 15 minutes to a week, then forever,
    /// with a stop for 8 am slotted in wherever it falls from right now.
    static func make(now: Date = Date()) -> [DurationStop] {
        let m = 60.0, h = 3600.0
        let base: [(String, TimeInterval?)] = [
            ("15m", 15 * m), ("30m", 30 * m), ("1h", h), ("2h", 2 * h), ("3h", 3 * h), ("4h", 4 * h),
            ("6h", 6 * h), ("8h", 8 * h), ("12h", 12 * h), ("1d", 24 * h), ("2d", 48 * h), ("1w", 168 * h),
            ("∞", nil),
        ]
        let morning = nextMorning(after: now).timeIntervalSince(now)
        var stops = base
            .filter { item in
                guard let d = item.1 else { return true }
                return abs(d - morning) >= 40 * m
            }
            .map { DurationStop(id: $0.0, label: $0.0, duration: $0.1, isMorning: false) }

        let index = stops.firstIndex { ($0.duration ?? .infinity) > morning } ?? stops.count - 1
        let label = nextMorning(after: now).formatted(.dateTime.hour()).lowercased()
            .replacingOccurrences(of: " ", with: "\u{2009}")
        stops.insert(DurationStop(id: "morning", label: label, duration: morning, isMorning: true), at: index)
        return stops
    }
}
