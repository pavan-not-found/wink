import Foundation

/// `wink://` commands, so scripts, Shortcuts and agent hooks can drive Wink.
///
///     open -g "wink://start?for=2h"        2h, 90m, 1d, 1w, 2h30m
///     open -g "wink://start?for=forever"
///     open -g "wink://start?until=08:00"
///     open -g "wink://start"               uses the last duration
///     open -g "wink://stop"   "wink://pause"   "wink://resume"   "wink://toggle"
///     open -g "wink://extend?by=1h"
///     open "wink://open"                   shows the popover
@MainActor
enum URLCommands {
    static func handle(_ url: URL, session: Session, show: () -> Void) {
        guard url.scheme?.lowercased() == "wink" else { return }
        let command = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        let q = Dictionary(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .compactMap { item in item.value.map { (item.name.lowercased(), $0) } } ?? [], uniquingKeysWith: { a, _ in a })

        switch command {
        case "start", "on":
            if let f = q["for"] {
                guard let d = parse(f) else { return }      // nonsense is ignored, not guessed at
                session.start(duration: d, interactive: false)
            } else if let u = q["until"] {
                guard let date = parseUntil(u) else { return }
                session.start(duration: date.timeIntervalSinceNow, interactive: false)
            } else {
                session.start(duration: session.selectedStop.resolvedDuration(), interactive: false)
            }
        case "stop", "off": session.stop()
        case "pause": session.pause()
        case "resume": session.resume()
        case "toggle": session.toggle()
        case "extend":
            if let b = q["by"], let d = parse(b), let d { session.extend(by: d) }
        case "open", "show": show()
        default: break
        }
    }

    /// "2h30m" -> 9000. "forever" -> .some(nil). Garbage -> nil.
    static func parse(_ s: String) -> TimeInterval?? {
        let s = s.lowercased().trimmingCharacters(in: .whitespaces)
        if ["forever", "inf", "infinite", "always", "∞"].contains(s) { return .some(nil) }
        if s.allSatisfy({ $0.isNumber || $0 == "." }), let n = Double(s) {   // bare number = minutes
            let t = n * 60
            return (t.isFinite && t > 0 && t <= Session.maxDuration) ? .some(t) : nil
        }
        let units: [Character: Double] = ["s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800]
        var total = 0.0, num = ""
        for ch in s {
            if ch.isNumber || ch == "." { num.append(ch); continue }
            guard let u = units[ch], let n = Double(num) else { return nil }
            total += n * u
            num = ""
        }
        guard num.isEmpty, total > 0, total.isFinite, total <= Session.maxDuration else { return nil }
        return .some(total)
    }

    static func parseUntil(_ s: String) -> Date? {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 1, parts[0] < 24 else { return nil }
        let cal = Calendar.current
        var date = cal.date(bySettingHour: parts[0], minute: parts.count > 1 ? parts[1] : 0, second: 0, of: Date()) ?? Date()
        if date <= Date() { date = cal.date(byAdding: .day, value: 1, to: date) ?? date }
        return date
    }
}
