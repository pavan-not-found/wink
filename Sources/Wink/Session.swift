import AppKit
import Combine

enum StopReason: String {
    case user, finished, lowBattery, hot
}

/// The single source of truth: is Wink keeping the Mac awake, and until when.
@MainActor
final class Session: ObservableObject {
    enum Mode: String { case off, running, paused }

    @Published private(set) var mode: Mode = .off
    @Published private(set) var total: TimeInterval?          // nil = forever
    @Published private(set) var endAt: Date?
    @Published private(set) var startedAt = Date()
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private(set) var now = Date()
    @Published private(set) var lastStop: StopReason?
    @Published private(set) var externalSleepDisabled = false
    @Published var notice: String?
    @Published var stops: [DurationStop] = Stops.make()
    @Published var selected: Int = 0

    let prefs: Prefs
    let power: Power
    private let live: Bool
    private var timer: Timer?
    private var ticks = 0
    private var observers: [NSObjectProtocol] = []

    /// Fired after anything visible changes (the menu bar listens to this).
    var onChange: (() -> Void)?

    init(prefs: Prefs, power: Power, live: Bool = true) {
        self.prefs = prefs
        self.power = power
        self.live = live
        selected = stops.firstIndex { $0.id == prefs.lastStopID } ?? stops.firstIndex { $0.id == "2h" } ?? 0
        guard live else { return }

        restore()
        power.recover(sessionRunning: mode == .running)
        refreshExternal()

        retime()

        observers.append(NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkGuards() }
        })
        applyPower()
    }

    // MARK: - Derived

    var isForever: Bool { total == nil }
    var selectedStop: DurationStop { stops[min(max(0, selected), stops.count - 1)] }

    var remaining: TimeInterval? {
        switch mode {
        case .running: return endAt.map { max(0, $0.timeIntervalSince(now)) }
        case .paused: return pausedRemaining
        case .off: return nil
        }
    }

    /// 1 at the start of a timed session, 0 at the end. Always 1 for forever.
    var fraction: Double {
        guard let total, total > 0, let remaining else { return 1 }
        return min(1, max(0, remaining / total))
    }

    var elapsed: TimeInterval { max(0, now.timeIntervalSince(startedAt)) }

    // MARK: - Actions

    func start() {
        let stop = selectedStop
        prefs.lastStopID = stop.id
        start(duration: stop.resolvedDuration())
    }

    /// Longest session Wink accepts: a year. Also guards against nonsense from URLs.
    static let maxDuration: TimeInterval = 366 * 86400

    static func clamp(_ d: TimeInterval?) -> TimeInterval? {
        guard let d else { return nil }
        guard d.isFinite else { return maxDuration }
        return min(max(d, 1), maxDuration)
    }

    /// `interactive` is false for wink:// commands: those never raise a password prompt.
    func start(duration rawDuration: TimeInterval?, interactive: Bool = true) {
        let duration = Self.clamp(rawDuration)
        if live, prefs.lidClosed, !power.lidHelperInstalled {
            if interactive { setUpLidClosed() }
            else { notice = "Open Wink and press Keep awake once to set up lid-closed mode. Until then it only works with the lid open." }
        }
        now = Date()
        total = duration
        startedAt = now
        endAt = duration.map { now.addingTimeInterval($0) }
        pausedRemaining = nil
        mode = .running
        lastStop = nil
        persist()
        applyPower()
    }

    func pause() {
        guard mode == .running else { return }
        pausedRemaining = endAt.map { max(0, $0.timeIntervalSinceNow) }
        mode = .paused
        persist()
        applyPower()
    }

    func resume() {
        guard mode == .paused else { return }
        now = Date()
        if let r = pausedRemaining { endAt = now.addingTimeInterval(r) }
        pausedRemaining = nil
        mode = .running
        persist()
        applyPower()
    }

    func stop(_ reason: StopReason = .user) {
        guard mode != .off else { return }
        mode = .off
        total = nil
        endAt = nil
        pausedRemaining = nil
        lastStop = reason == .user ? nil : reason
        refreshStops()
        persist()
        applyPower()
    }

    func extend(by t: TimeInterval) {
        guard mode != .off, let current = total, t.isFinite, t > 0 else { return }
        let t = min(t, Self.maxDuration - current)
        guard t > 0 else { return }
        total = current + t
        if mode == .running { endAt = endAt?.addingTimeInterval(t) }
        if mode == .paused { pausedRemaining = (pausedRemaining ?? 0) + t }
        persist()
        onChange?()
    }

    func toggle() {
        switch mode {
        case .off: start()
        case .running: pause()
        case .paused: resume()
        }
    }

    func step(_ delta: Int) {
        selected = min(max(0, selected + delta), stops.count - 1)
    }

    func refreshStops() {
        let id = selectedStop.id
        stops = Stops.make()
        selected = stops.firstIndex { $0.id == id } ?? min(selected, stops.count - 1)
    }

    /// Called when the person flips "lid closed" on, or on first start.
    @discardableResult
    func setUpLidClosed() -> Bool {
        if power.lidHelperInstalled { return true }
        switch power.installLidHelper() {
        case .success:
            notice = nil
            return true
        case .failure(let e):
            prefs.lidClosed = false
            notice = e.text
            return false
        }
    }

    func restoreNormalSleep() {
        switch power.restoreNormalSleep() {
        case .success: notice = nil
        case .failure(let e): if e != .cancelled { notice = e.text }
        }
        refreshExternal()
        applyPower()
    }

    /// Quitting Wink means "let my Mac sleep normally again", so the session ends.
    func prepareForQuit() {
        if mode != .off {
            mode = .off; total = nil; endAt = nil; pausedRemaining = nil
            persist()
        }
        power.setAwake(false, keepDisplayOn: false)
        power.releaseLidClosed()
    }

    // MARK: - Ticking

    /// Set by the menu bar controller. The clock only ticks every second while
    /// something is on screen that needs it; otherwise every 30 seconds.
    var popoverVisible = false { didSet { if popoverVisible != oldValue { retime() } } }
    private var currentInterval: TimeInterval = 0
    private var lastGuardCheck = Date.distantPast
    private var lastStopsRefresh = Date()

    private func retime() {
        guard live else { return }
        let interval: TimeInterval = (mode != .off || popoverVisible) ? 1 : 30
        guard interval != currentInterval else { return }
        currentInterval = interval
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = interval * 0.15
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    private func tick() {
        let n = Date()
        ticks += 1
        if mode == .running, let e = endAt, e <= n { now = n; stop(.finished) }
        if n.timeIntervalSince(lastGuardCheck) >= 10 { lastGuardCheck = n; checkGuards(); refreshExternal() }
        if mode == .off, n.timeIntervalSince(lastStopsRefresh) >= 60 { lastStopsRefresh = n; refreshStops() }
        if mode != .off || popoverVisible { now = n }
        onChange?()
    }

    private func checkGuards() {
        guard mode == .running else { return }
        if prefs.batteryGuard, let b = Battery.read(), !b.onAC, b.percent <= prefs.batteryThreshold {
            stop(.lowBattery)
        } else if ProcessInfo.processInfo.thermalState == .critical {
            stop(.hot)
        }
    }

    func applyPower() {
        let awake = mode == .running
        power.setAwake(awake, keepDisplayOn: prefs.keepDisplayOn)
        if awake && prefs.lidClosed {
            if !power.holdLidClosed() && power.lidHelperInstalled {
                notice = "Couldn't switch lid-closed sleep off. Try turning the lid switch off and on."
            }
        } else if !power.releaseLidClosed() {
            notice = "Wink couldn't switch normal sleep back on by itself. Use the button above to do it with your password."
        }
        refreshExternal()
        onChange?()
    }

    func refreshExternal() {
        let value = live && mode == .off && power.systemSleepDisabled
        if value != externalSleepDisabled { externalSleepDisabled = value }
    }

    // MARK: - Persistence (so a relaunch carries on)

    private func persist() {
        guard live else { return }
        retime()
        let d = UserDefaults.standard
        d.set(mode.rawValue, forKey: "session.mode")
        d.set(total, forKey: "session.total")
        d.set(endAt?.timeIntervalSince1970, forKey: "session.endAt")
        d.set(startedAt.timeIntervalSince1970, forKey: "session.startedAt")
        d.set(pausedRemaining, forKey: "session.pausedRemaining")
    }

    private func restore() {
        let d = UserDefaults.standard
        guard let raw = d.string(forKey: "session.mode"), let m = Mode(rawValue: raw), m != .off else { return }
        total = d.object(forKey: "session.total") as? Double
        endAt = (d.object(forKey: "session.endAt") as? Double).map(Date.init(timeIntervalSince1970:))
        startedAt = (d.object(forKey: "session.startedAt") as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
        pausedRemaining = d.object(forKey: "session.pausedRemaining") as? Double
        mode = m
        if m == .running, let e = endAt, e <= Date() {
            mode = .off; total = nil; endAt = nil
        }
    }

    // MARK: - Demo states (screenshots only)

    func demo(mode: Mode, total: TimeInterval?, remaining: TimeInterval?, elapsed: TimeInterval = 0, selectedID: String? = nil) {
        let n = Date()
        self.now = n
        self.mode = mode
        self.total = total
        self.startedAt = n.addingTimeInterval(-elapsed)
        if mode == .running { endAt = remaining.map { n.addingTimeInterval($0) } }
        if mode == .paused { pausedRemaining = remaining }
        if let selectedID, let i = stops.firstIndex(where: { $0.id == selectedID }) { selected = i }
    }

    func demoExternal(_ on: Bool) { externalSleepDisabled = on }
    func demoLastStop(_ r: StopReason?) { lastStop = r }
}
