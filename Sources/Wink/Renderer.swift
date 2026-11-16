import AppKit
import SwiftUI

/// `Wink --render <dir>` writes crisp PNGs of every popover state, the menu bar
/// glyphs and the app icon. Used for the README, the site and launch posts.
/// It never touches the system's power settings.
@MainActor
enum Renderer {
    static func run(dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let prefs = Prefs(defaults: UserDefaults(suiteName: "wink.render.\(UUID().uuidString)")!)

        struct Shot { let name: String; let setup: (Session) -> Void; var settings = false }
        let shots: [Shot] = [
            Shot(name: "setup", setup: { $0.demo(mode: .off, total: nil, remaining: nil, selectedID: "2h") }),
            Shot(name: "setup-morning", setup: { $0.demo(mode: .off, total: nil, remaining: nil, selectedID: "morning") }),
            Shot(name: "setup-forever", setup: { $0.demo(mode: .off, total: nil, remaining: nil, selectedID: "∞") }),
            Shot(name: "running", setup: { $0.demo(mode: .running, total: 7200, remaining: 4728) }),
            Shot(name: "running-forever", setup: { $0.demo(mode: .running, total: nil, remaining: nil, elapsed: 11_532) }),
            Shot(name: "paused", setup: { $0.demo(mode: .paused, total: 7200, remaining: 4728) }),
            Shot(name: "banner", setup: { $0.demo(mode: .off, total: nil, remaining: nil, selectedID: "2h"); $0.demoExternal(true) }),
            Shot(name: "finished", setup: { $0.demo(mode: .off, total: nil, remaining: nil, selectedID: "2h"); $0.demoLastStop(.lowBattery) }),
        ]

        for scheme in [ColorScheme.dark, .light] {
            for shot in shots {
                let session = Session(prefs: prefs, power: Power(dryRun: true), live: false)
                shot.setup(session)
                let view = PopoverView()
                    .environmentObject(session)
                    .environmentObject(prefs)
                    .background(chrome(scheme))
                    .environment(\.colorScheme, scheme)
                    .padding(40)
                write(view, to: dir.appendingPathComponent("popover-\(shot.name)-\(scheme == .dark ? "dark" : "light").png"))
            }
            let session = Session(prefs: prefs, power: Power(dryRun: true), live: false)
            let settings = SettingsView(close: {})
                .environmentObject(session).environmentObject(prefs)
                .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 12).frame(width: 300)
                .background(chrome(scheme))
                .environment(\.colorScheme, scheme)
                .padding(40)
            write(settings, to: dir.appendingPathComponent("popover-settings-\(scheme == .dark ? "dark" : "light").png"))
        }

        // Menu bar glyphs at 4x, in amber/white/black
        let looks: [(String, MenuBarIcon.Look)] = [
            ("off", .off), ("forever", .forever), ("awake-75", .awake(0.75)), ("awake-40", .awake(0.4)),
            ("awake-10", .awake(0.1)), ("paused", .paused(0.4)),
        ]
        for (name, look) in looks {
            for (suffix, tint) in [("white", NSColor.white), ("black", NSColor.black)] {
                let img = MenuBarIcon.image(look)
                let px = NSSize(width: 80, height: 72)
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px.width), pixelsHigh: Int(px.height),
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                img.draw(in: NSRect(origin: .zero, size: px))
                if img.isTemplate {
                    tint.set()
                    NSRect(origin: .zero, size: px).fill(using: .sourceAtop)
                }
                NSGraphicsContext.restoreGraphicsState()
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: dir.appendingPathComponent("glyph-\(name)-\(suffix).png"))
            }
        }

        // App icon
        try? AppIconArt.png(size: 1024)?.write(to: dir.appendingPathComponent("app-icon-1024.png"))
        print("Rendered to \(dir.path)")
    }

    /// Frames for the launch film: the ruler at each stop, then running till morning.
    static func runVideo(dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let prefs = Prefs(defaults: UserDefaults(suiteName: "wink.render.\(UUID().uuidString)")!)
        let probe = Session(prefs: prefs, power: Power(dryRun: true), live: false)
        for stop in probe.stops {
            let s = Session(prefs: prefs, power: Power(dryRun: true), live: false)
            s.demo(mode: .off, total: nil, remaining: nil, selectedID: stop.id)
            let safe = stop.id == "∞" ? "forever" : stop.id
            write(frame(s, prefs), to: dir.appendingPathComponent("setup-\(safe).png"))
        }
        let morning = Stops.nextMorning().timeIntervalSinceNow
        for (name, left) in [("running-start", morning), ("running-later", morning * 0.42)] {
            let s = Session(prefs: prefs, power: Power(dryRun: true), live: false)
            s.demo(mode: .running, total: morning, remaining: left, elapsed: morning - left)
            write(frame(s, prefs), to: dir.appendingPathComponent("\(name).png"))
        }
        print("Video frames in \(dir.path) (morning = \(Int(morning))s)")
    }

    private static func frame(_ s: Session, _ prefs: Prefs) -> some View {
        PopoverView()
            .environmentObject(s)
            .environmentObject(prefs)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.145, green: 0.137, blue: 0.165))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.1))))
            .environment(\.colorScheme, .dark)
    }

    private static func chrome(_ scheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(scheme == .dark ? Color(red: 0.145, green: 0.137, blue: 0.165) : Color(red: 0.965, green: 0.957, blue: 0.972))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.18), radius: 24, y: 14)
    }

    private static func write<V: View>(_ view: V, to url: URL) {
        let r = ImageRenderer(content: view)
        r.scale = 3
        guard let cg = r.cgImage else { print("render failed: \(url.lastPathComponent)"); return }
        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
    }
}
