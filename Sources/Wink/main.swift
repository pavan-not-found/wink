import AppKit

let args = CommandLine.arguments

// Tooling modes (used by scripts/build.sh and for launch assets)
if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
    _ = NSApplication.shared
    MainActor.assumeIsolated { Renderer.run(dir: URL(fileURLWithPath: args[i + 1])) }
    exit(0)
}
if let i = args.firstIndex(of: "--render-video"), i + 1 < args.count {
    _ = NSApplication.shared
    MainActor.assumeIsolated { Renderer.runVideo(dir: URL(fileURLWithPath: args[i + 1])) }
    exit(0)
}
if let i = args.firstIndex(of: "--iconset"), i + 1 < args.count {
    do { try AppIconArt.writeIconset(to: URL(fileURLWithPath: args[i + 1])); exit(0) }
    catch { print(error); exit(1) }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
