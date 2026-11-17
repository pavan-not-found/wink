import AppKit
import IOKit.pwr_mgt

@_silgen_name("IOPMCopySystemPowerSettings")
private func IOPMCopySystemPowerSettings() -> Unmanaged<CFDictionary>?

/// Everything that touches the system's sleep behaviour lives here.
///
/// Two separate mechanisms:
/// 1. A power assertion (no privileges needed). Stops idle sleep while the lid is open.
/// 2. `pmset -a disablesleep 1` (needs root). The only thing that keeps a MacBook
///    running with the lid shut on battery. Wink installs a sudoers rule once that
///    allows exactly `pmset -a disablesleep 0` and `pmset -a disablesleep 1`.
///
/// Wink records when it switched sleep off, so a crash or force-quit is repaired
/// on the next launch, and it never touches the setting if something else set it.
final class Power {
    static let sudoersPath = "/etc/sudoers.d/wink"

    let dryRun: Bool
    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0
    private let defaults = UserDefaults.standard

    init(dryRun: Bool = false) {
        self.dryRun = dryRun
    }

    // MARK: - State

    /// True when Wink itself switched `disablesleep` on and still has to switch it back.
    var ownsSleepDisabled: Bool {
        get { defaults.bool(forKey: "ownsSleepDisabled") }
        set { defaults.set(newValue, forKey: "ownsSleepDisabled") }
    }

    /// The live system value of `SleepDisabled`, whoever set it.
    var systemSleepDisabled: Bool {
        if dryRun { return false }
        guard let dict = IOPMCopySystemPowerSettings()?.takeRetainedValue() as? [String: Any] else { return false }
        if let n = dict["SleepDisabled"] as? NSNumber { return n.boolValue }
        return false
    }

    var lidHelperInstalled: Bool {
        if dryRun { return true }
        return FileManager.default.fileExists(atPath: Self.sudoersPath)
    }

    // MARK: - Lid open: assertions

    func setAwake(_ on: Bool, keepDisplayOn: Bool) {
        if dryRun { return }
        set(&systemAssertion, on: on, type: kIOPMAssertionTypePreventUserIdleSystemSleep)
        set(&displayAssertion, on: on && keepDisplayOn, type: kIOPMAssertionTypePreventUserIdleDisplaySleep)
    }

    private func set(_ id: inout IOPMAssertionID, on: Bool, type: String) {
        if on, id == 0 {
            IOPMAssertionCreateWithName(type as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "Wink is keeping your Mac awake" as CFString,
                                        &id)
        } else if !on, id != 0 {
            IOPMAssertionRelease(id)
            id = 0
        }
    }

    // MARK: - Lid closed: disablesleep

    /// Turns lid-closed sleep off. Returns false if Wink can't (helper missing or sudo refused).
    @discardableResult
    func holdLidClosed() -> Bool {
        if dryRun { return true }
        if ownsSleepDisabled {
            // Ours already, e.g. relaunched mid-session. If something switched it back on
            // in the meantime (the crash watcher, or someone running pmset), switch it off again.
            if !systemSleepDisabled {
                guard lidHelperInstalled, pmset(disable: true) else { ownsSleepDisabled = false; return false }
            }
            if watcher?.isRunning != true { startWatcher() }
            return true
        }
        if systemSleepDisabled { return true }          // already off, and not ours: leave it alone
        guard lidHelperInstalled, pmset(disable: true) else { return false }
        ownsSleepDisabled = true
        startWatcher()
        return true
    }

    /// A tiny shell loop that outlives Wink. If Wink dies without cleaning up
    /// (force quit, crash), it switches lid-closed sleep back on within seconds
    /// and clears Wink's ownership flag.
    private var watcher: Process?

    private func startWatcher() {
        stopWatcher()
        let pid = ProcessInfo.processInfo.processIdentifier
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 2; done; " + Self.restoreScript]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        watcher = p
    }

    private func stopWatcher() {
        if let w = watcher, w.isRunning { w.terminate() }
        watcher = nil
    }

    static var defaultsDomain: String { Bundle.main.bundleIdentifier ?? "app.wink.mac" }

    /// Shell that switches sleep back on if Wink still owns it. Shared by the crash
    /// watcher and the login agent that covers hard shutdowns.
    static var restoreScript: String {
        let d = defaultsDomain
        return "if [ \"$(/usr/bin/defaults read \(d) ownsSleepDisabled 2>/dev/null)\" = 1 ]; then " +
            "/usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 && /usr/bin/defaults write \(d) ownsSleepDisabled -bool false; fi"
    }

    /// Turns lid-closed sleep back on, but only if Wink was the one that turned it off.
    /// Returns false if it couldn't; the watcher then stays in place as a backstop.
    @discardableResult
    func releaseLidClosed() -> Bool {
        if dryRun || !ownsSleepDisabled { return true }
        if pmset(disable: false) || !systemSleepDisabled {
            ownsSleepDisabled = false
            stopWatcher()
            return true
        }
        return false
    }

    /// Called at launch. If Wink died while holding the lid, put things back.
    func recover(sessionRunning: Bool) {
        if !sessionRunning { releaseLidClosed() }
    }

    /// For Macs where something else (usually a `sudo pmset disablesleep 1` someone
    /// forgot about) has switched sleep off. Turns it back on so Wink can manage it.
    func restoreNormalSleep() -> Result<Void, PowerError> {
        if lidHelperInstalled, pmset(disable: false) { ownsSleepDisabled = false; stopWatcher(); return .success(()) }
        let r = admin("/usr/bin/pmset -a disablesleep 0",
                      prompt: "Wink needs your password to turn normal sleep back on.")
        if case .success = r { ownsSleepDisabled = false; stopWatcher() }
        return r
    }

    // MARK: - Helper install

    func installLidHelper() -> Result<Void, PowerError> {
        let user = NSUserName()
        guard user.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
            return .failure(.message("Wink couldn't read your account name."))
        }
        let lines = [
            "# Added by Wink (https://github.com/pavan-not-found/wink) so it can keep your Mac",
            "# awake with the lid closed. It allows exactly these two commands, nothing else.",
            "# To remove it: sudo rm /etc/sudoers.d/wink",
            "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1",
        ]
        // Written, checked and moved entirely as root inside /etc/sudoers.d, so nothing
        // the user can write is read back after visudo validates it. sudo ignores
        // files whose names start with a dot, so the temp file is never live.
        let tmp = "/etc/sudoers.d/.wink.new"
        let printf = "/usr/bin/printf '%s\\n' " + lines.map { "'\($0)'" }.joined(separator: " ")
        let cmd = "umask 077; \(printf) > \(tmp) && /usr/sbin/visudo -cf \(tmp) && " +
            "/usr/sbin/chown root:wheel \(tmp) && /bin/chmod 0440 \(tmp) && /bin/mv -f \(tmp) \(Self.sudoersPath) " +
            "|| { /bin/rm -f \(tmp); exit 1; }"
        let r = admin(cmd, prompt: "Wink needs your password once so it can keep your Mac awake with the lid closed.")
        if case .success = r { installLoginAgent() }
        return r
    }

    /// A login agent that runs the restore script once at login. It covers the one case the
    /// watcher can't: a hard shutdown or kernel panic while Wink held lid-closed sleep off.
    static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(defaultsDomain).restore-sleep.plist")
    }

    private func installLoginAgent() {
        let plist: [String: Any] = [
            "Label": "\(Self.defaultsDomain).restore-sleep",
            "ProgramArguments": ["/bin/sh", "-c", Self.restoreScript],
            "RunAtLoad": true,
        ]
        try? FileManager.default.createDirectory(at: Self.agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        (plist as NSDictionary).write(to: Self.agentURL, atomically: true)
    }

    func uninstallLidHelper() -> Result<Void, PowerError> {
        // Put sleep back first. If sudo can't, do it as part of the same admin step.
        let restored = releaseLidClosed()
        let restore = restored ? "" : "/usr/bin/pmset -a disablesleep 0; "
        let r = admin(restore + "/bin/rm -f \(Self.sudoersPath)", prompt: "Wink needs your password to remove its lid-closed permission.")
        if case .success = r {
            if !restored { ownsSleepDisabled = false; stopWatcher() }
            try? FileManager.default.removeItem(at: Self.agentURL)
        }
        return r
    }

    // MARK: - Plumbing

    private func pmset(disable: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", disable ? "1" : "0"]) == 0
    }

    private func run(_ path: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }

    private func admin(_ command: String, prompt: String) -> Result<Void, PowerError> {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        }
        let source = "do shell script \"\(esc(command))\" with prompt \"\(esc(prompt))\" with administrator privileges"
        var error: NSDictionary?
        NSApp.activate(ignoringOtherApps: true)
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -128 { return .failure(.cancelled) }
            return .failure(.message(error[NSAppleScript.errorMessage] as? String ?? "Something went wrong."))
        }
        return .success(())
    }
}

enum PowerError: Error, Equatable {
    case cancelled
    case message(String)

    var text: String {
        switch self {
        case .cancelled: return "Cancelled. Wink will only keep your Mac awake while the lid is open."
        case .message(let m): return m
        }
    }
}
