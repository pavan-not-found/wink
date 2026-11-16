import AppKit
import SwiftUI

enum Theme {
    static let amberNS = NSColor(name: "WinkAmber") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.0, green: 0.702, blue: 0.251, alpha: 1)       // #FFB340
            : NSColor(srgbRed: 0.91, green: 0.576, blue: 0.047, alpha: 1)      // #E8930C
    }
    static let amber = Color(nsColor: amberNS)
    static let onAmber = Color(red: 0.17, green: 0.10, blue: 0.0)
}

/// The Wink mark: a single eye under a heavy, flat lid.
///
/// Built on a 24-unit grid from one circle of radius R:
/// - the lower lid is the bottom half of that circle, drawn as a stroke of width w
/// - the upper lid is a flat bar of the same width, spanning the same diameter
/// - the pupil is a disc on the same centre, clipped by the upper lid
///
/// `open` runs from 0 (lid down on the centre line: a closed eye) to 1 (lid at the
/// top of the circle: wide awake). While a timer runs, the lid comes down with it.
enum Eye {
    static let center = CGPoint(x: 12, y: 11.4)
    static let R: CGFloat = 8.6
    static let w: CGFloat = 2.5
    static let pupil: CGFloat = 4.9
    static let gap: CGFloat = 1.35

    /// Fully open, the lid rests just above the pupil; fully shut, it sits on the centre line.
    static var lidTop: CGFloat { center.y - pupil - gap - w / 2 }
    static func lidY(open: CGFloat) -> CGFloat {
        let o = max(0, min(1, open))
        return lidTop + (1 - o) * (center.y - lidTop)
    }

    /// Draws into a y-down context already scaled so the mark spans 24 units.
    static func draw(in ctx: CGContext, open: CGFloat, lid: CGColor, pupilColor: CGColor?, hollowPupil: Bool = false, pupilShadow: CGColor? = nil) {
        let c = center, yl = lidY(open: open)
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineWidth(w)
        ctx.setStrokeColor(lid)

        // lower lid: bottom half of the circle
        let bowl = CGMutablePath()
        bowl.addRelativeArc(center: c, radius: R, startAngle: 0, delta: .pi)
        ctx.addPath(bowl)
        ctx.strokePath()

        // upper lid: a flat bar across the same diameter
        ctx.move(to: CGPoint(x: c.x - R, y: yl))
        ctx.addLine(to: CGPoint(x: c.x + R, y: yl))
        ctx.strokePath()
        ctx.restoreGState()

        // pupil, below the lid and inside the eye
        guard let pupilColor, open > 0.001 else { return }
        ctx.saveGState()
        let top = yl + w / 2 + gap
        ctx.clip(to: CGRect(x: 0, y: top, width: 24, height: 24 - top))
        let inner = R - w / 2 - gap
        ctx.addEllipse(in: CGRect(x: c.x - inner, y: c.y - inner, width: inner * 2, height: inner * 2))
        ctx.clip()
        let r = pupil
        let disc = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        if hollowPupil {
            ctx.setStrokeColor(pupilColor)
            ctx.setLineWidth(w * 0.72)
            ctx.strokeEllipse(in: disc.insetBy(dx: w * 0.36, dy: w * 0.36))
        } else {
            if let pupilShadow { ctx.setShadow(offset: .zero, blur: 3, color: pupilShadow) }
            ctx.setFillColor(pupilColor)
            ctx.fillEllipse(in: disc)
        }
        ctx.restoreGState()
    }
}

/// Menu bar rendering.
enum MenuBarIcon {
    enum Look { case off, awake(Double), forever, paused(Double) }

    /// While a timer runs the eye never quite shuts; it shuts when Wink stops.
    static func openness(for fraction: Double) -> CGFloat { CGFloat(0.18 + 0.82 * fraction) }

    static func image(_ look: Look) -> NSImage {
        let size = NSSize(width: 20, height: 18)
        let template: Bool
        switch look { case .off, .paused: template = true; default: template = false }

        let img = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = rect.height / 24 * 1.06
            ctx.translateBy(x: (rect.width - 24 * s) / 2, y: (rect.height - 24 * s) / 2 + 0.4)
            ctx.scaleBy(x: s, y: s)
            let black = NSColor.black.cgColor
            let amber = NSColor(srgbRed: 1.0, green: 0.702, blue: 0.251, alpha: 1).cgColor
            switch look {
            case .off:
                Eye.draw(in: ctx, open: 0, lid: black, pupilColor: nil)
            case .paused(let f):
                Eye.draw(in: ctx, open: openness(for: f), lid: black, pupilColor: black, hollowPupil: true)
            case .awake(let f):
                Eye.draw(in: ctx, open: openness(for: f), lid: amber, pupilColor: amber)
            case .forever:
                Eye.draw(in: ctx, open: 1, lid: amber, pupilColor: amber)
            }
            return true
        }
        img.isTemplate = template
        img.accessibilityDescription = "Wink"
        return img
    }
}

/// The app icon, drawn with the same geometry. Used to generate AppIcon.icns.
enum AppIconArt {
    static func png(size px: Int) -> Data? {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let S = CGFloat(px)
        ctx.translateBy(x: 0, y: S)
        ctx.scaleBy(x: 1, y: -1)        // y-down from here on

        // macOS icon grid: 824/1024 body, continuous-corner radius ~ 185/1024
        let body = CGRect(x: S * 100 / 1024, y: S * 100 / 1024, width: S * 824 / 1024, height: S * 824 / 1024)
        let shape = CGPath(roundedRect: body, cornerWidth: S * 185 / 1024, cornerHeight: S * 185 / 1024, transform: nil)

        // drop shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: S * 10 / 1024), blur: S * 24 / 1024,
                      color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.35))
        ctx.addPath(shape); ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)); ctx.fillPath()
        ctx.restoreGState()

        // background gradient
        ctx.saveGState()
        ctx.addPath(shape); ctx.clip()
        let bg = CGGradient(colorsSpace: cs, colors: [
            CGColor(srgbRed: 0.165, green: 0.161, blue: 0.188, alpha: 1),
            CGColor(srgbRed: 0.047, green: 0.047, blue: 0.059, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: body.minY), end: CGPoint(x: 0, y: body.maxY), options: [])

        // warm glow behind the pupil
        let glowC = CGPoint(x: S / 2, y: S * 0.535)
        let glow = CGGradient(colorsSpace: cs, colors: [
            CGColor(srgbRed: 1, green: 0.70, blue: 0.25, alpha: 0.30),
            CGColor(srgbRed: 1, green: 0.70, blue: 0.25, alpha: 0),
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: glowC, startRadius: 0, endCenter: glowC, endRadius: S * 0.36, options: [])

        // the eye
        let markSize = S * 0.60
        let s = markSize / 24
        ctx.translateBy(x: (S - markSize) / 2, y: (S - markSize) / 2 + S * 0.01)
        ctx.scaleBy(x: s, y: s)
        let cream = CGColor(srgbRed: 0.949, green: 0.937, blue: 0.914, alpha: 1)
        let amber = CGColor(srgbRed: 1.0, green: 0.702, blue: 0.251, alpha: 1)
        Eye.draw(in: ctx, open: 1, lid: cream, pupilColor: amber,
                 pupilShadow: CGColor(srgbRed: 1, green: 0.6, blue: 0.1, alpha: 0.9))
        ctx.restoreGState()

        // hairline edge
        ctx.addPath(shape)
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10))
        ctx.setLineWidth(max(1, S / 512))
        ctx.strokePath()

        guard let cg = ctx.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }

    static func writeIconset(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let px = base * scale
                let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
                try png(size: px)?.write(to: dir.appendingPathComponent(name))
            }
        }
    }
}
