import Foundation

enum Fmt {
    private static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "AM", with: "am")
            .replacingOccurrences(of: "PM", with: "pm")
    }

    /// "11:47 pm", "tomorrow 8:00 am", "Wednesday 9:41 pm", "Mon 23 Nov, 9:41 pm"
    static func until(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let t = clock(date)
        if cal.isDate(date, inSameDayAs: now) { return t }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: tomorrow) {
            return "tomorrow \(t)"
        }
        if date.timeIntervalSince(now) < 6 * 86400 {
            return "\(date.formatted(.dateTime.weekday(.wide))) \(t)"
        }
        return "\(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))), \(t)"
    }

    /// Big countdown: ("1:58", ":12") or ("3d 4h", nil)
    /// Keeps Int conversions safe whatever comes in.
    private static func safe(_ t: TimeInterval) -> TimeInterval { t.isFinite ? min(max(0, t), 1e9) : 0 }

    static func countdown(_ t: TimeInterval) -> (main: String, seconds: String?) {
        let s = Int(safe(t).rounded(.down))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h >= 48 { return ("\(h / 24)d \(h % 24)h", nil) }
        return ("\(h):\(String(format: "%02d", m))", String(format: ":%02d", sec))
    }

    /// Compact form for the menu bar: "1:58", "42m", "3d"
    static func short(_ t: TimeInterval) -> String {
        let t = safe(t)
        if t < 60 { return "\(Int(t.rounded(.up)))s" }
        let m = Int((t / 60).rounded(.down)), h = m / 60
        if h >= 48 { return "\(h / 24)d" }
        if h > 0 { return "\(h):\(String(format: "%02d", m % 60))" }
        return "\(m)m"
    }

    /// "3h 12m", "45m"
    static func words(_ t: TimeInterval) -> String {
        let m = Int((safe(t) / 60).rounded(.down)), h = m / 60
        if h >= 24 { return "\(h / 24)d \(h % 24)h" }
        if h > 0 { return "\(h)h \(m % 60)m" }
        return "\(m)m"
    }

    /// The hero label above the ruler: ("2", "hours"), ("Forever", nil)
    static func hero(_ stop: DurationStop) -> (big: String, unit: String?) {
        if stop.duration == nil { return ("Forever", nil) }
        if stop.isMorning { return ("Till morning", nil) }
        let mins = Int((stop.duration ?? 0) / 60)
        if mins < 60 { return ("\(mins)", "min") }
        let h = mins / 60
        if h < 24 { return ("\(h)", h == 1 ? "hour" : "hours") }
        let d = h / 24
        if d == 7 { return ("1", "week") }
        return ("\(d)", d == 1 ? "day" : "days")
    }
}
