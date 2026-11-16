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
        if dryRun || ownsSleepDisabled { return true }
        if systemSleepDisabled { return true }          // already off, and not ours: leave it alone
        guard lidHelperInstalled, pmset(disable: true) else { return false }
        ownsSleepDisabled = true
        startWatcher()
        return true
    }

    /// A tiny shell loop that outlives Wink. If Wink dies without cleaning up
    /// (force quit, crash), it switches lid-closed sleep back on within seconds.
    private var watcher: Process?

    private func startWatcher() {
        stopWatcher()
        let pid = ProcessInfo.processInfo.processIdentifier
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 2; done; /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        watcher = p
    }

    private func stopWatcher() {
        if let w = watcher, w.isRunning { w.terminate() }
        watcher = nil
    }

    /// Turns lid-closed sleep back on, but only if Wink was the one that turned it off.
    func releaseLidClosed() {
        if dryRun || !ownsSleepDisabled { return }
        stopWatcher()
        if pmset(disable: false) || !systemSleepDisabled {
            ownsSleepDisabled = false
        }
    }

    /// Called at launch. If Wink died while holding the lid, put things back.
    func recover(sessionRunning: Bool) {
        if !sessionRunning { releaseLidClosed() }
    }

    /// For Macs where something else (usually a `sudo pmset disablesleep 1` someone
    /// forgot about) has switched sleep off. Turns it back on so Wink can manage it.
    func restoreNormalSleep() -> Result<Void, PowerError> {
        if lidHelperInstalled, pmset(disable: false) { return .success(()) }
        return admin("/usr/bin/pmset -a disablesleep 0",
                     prompt: "Wink needs your password to turn normal sleep back on.")
    }

    // MARK: - Helper install

    func installLidHelper() -> Result<Void, PowerError> {
        let user = NSUserName()
        guard user.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
            return .failure(.message("Wink couldn't read your account name."))
        }
        let rule = """
        # Added by Wink (https://github.com/pavan-parallel/wink) so it can keep your Mac
        # awake with the lid closed. It allows exactly these two commands, nothing else.
        # To remove it: sudo rm /etc/sudoers.d/wink
        \(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1

        """
        let tmp = (NSTemporaryDirectory() as NSString).appendingPathComponent("wink-sudoers-\(UUID().uuidString)")
        do { try rule.write(toFile: tmp, atomically: true, encoding: .utf8) }
        catch { return .failure(.message("Wink couldn't write a temporary file.")) }
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let cmd = "/usr/sbin/visudo -cf '\(tmp)' && /usr/bin/install -m 0440 -o root -g wheel '\(tmp)' \(Self.sudoersPath)"
        return admin(cmd, prompt: "Wink needs your password once so it can keep your Mac awake with the lid closed.")
    }

    func uninstallLidHelper() -> Result<Void, PowerError> {
        releaseLidClosed()
        return admin("/bin/rm -f \(Self.sudoersPath)", prompt: "Wink needs your password to remove its lid-closed permission.")
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
