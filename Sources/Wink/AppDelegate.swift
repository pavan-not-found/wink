import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var session: Session!
    private var prefs: Prefs!
    private var lastIconKey = ""
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        prefs = Prefs()
        session = Session(prefs: prefs, power: Power())

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeft
            button.imageHugsTitle = true
        }

        let host = NSHostingController(rootView: PopoverView()
            .environmentObject(session)
            .environmentObject(prefs))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        session.onChange = { [weak self] in self?.refreshStatusItem() }
        refreshStatusItem()

        // `kill`, logout scripts and the like: clean up before going.
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.session.prepareForQuit() }
                exit(0)
            }
            src.resume()
            signalSources.append(src)
        }

        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
    }

    func popoverWillShow(_ notification: Notification) { session.popoverVisible = true }
    func popoverDidClose(_ notification: Notification) { session.popoverVisible = false }

    func applicationWillTerminate(_ notification: Notification) {
        session?.prepareForQuit()
    }

    // MARK: - Menu bar

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown { popover.performClose(sender) } else { showPopover() }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        if session.mode == .off { session.refreshStops() }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        let look: MenuBarIcon.Look
        var title = ""
        var titleColor = NSColor.labelColor
        switch session.mode {
        case .off:
            look = .off
        case .paused:
            look = .paused(session.fraction)
            if let r = session.remaining { title = Fmt.short(r); titleColor = .secondaryLabelColor }
        case .running:
            if session.isForever {
                look = .forever
            } else {
                look = .awake(session.fraction)
                if let r = session.remaining { title = Fmt.short(r); titleColor = Theme.amberNS }
            }
        }

        // Only redraw when something visible changed.
        let key = "\(session.mode)-\(Int(session.fraction * 40))-\(title)"
        guard key != lastIconKey else { return }
        lastIconKey = key

        button.image = MenuBarIcon.image(look)
        if title.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            button.attributedTitle = NSAttributedString(string: " " + title, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: titleColor,
                .baselineOffset: 0.5,
            ])
        }
        switch session.mode {
        case .off: button.toolTip = "Wink: your Mac sleeps normally"
        case .paused: button.toolTip = "Wink: paused"
        case .running: button.toolTip = session.isForever ? "Wink: awake until you stop it"
            : "Wink: awake until \(Fmt.until(session.endAt ?? Date()))"
        }
        button.setAccessibilityLabel(button.toolTip)
    }

    // MARK: - URL scheme

    @objc private func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, let url = URL(string: s) else { return }
        if url.host == "debug-snapshot", UserDefaults.standard.bool(forKey: "debugSnapshots") {
            // Always inside a fixed temp folder; the name is reduced to safe characters.
            let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "name" }?.value ?? "latest"
            let name = String(raw.filter { $0.isLetter || $0.isNumber || $0 == "-" }.prefix(40))
            snapshot(to: URL(fileURLWithPath: "/tmp/wink-snapshots").appendingPathComponent(name.isEmpty ? "latest" : name))
            return
        }
        URLCommands.handle(url, session: session, show: { [weak self] in self?.showPopover() })
    }

    /// Debug only (needs `defaults write app.wink.mac debugSnapshots -bool true`):
    /// renders Wink's own menu bar item and popover, no screen-recording permission needed.
    private func snapshot(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func save(_ view: NSView, _ name: String) {
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(name))
        }
        if let b = statusItem.button { save(b, "statusitem.png") }
        if popover.isShown, let v = popover.contentViewController?.view.window?.contentView { save(v, "popover.png") }
        let info = "mode=\(session.mode) remaining=\(session.remaining.map { Int($0) } ?? -1) fraction=\(session.fraction) title=\(statusItem.button?.title ?? "")"
        try? info.write(to: dir.appendingPathComponent("state.txt"), atomically: true, encoding: .utf8)
    }
}
