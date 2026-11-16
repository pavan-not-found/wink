import SwiftUI

struct AmberButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.onAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.amber)
                    .brightness(configuration.isPressed ? -0.06 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct RoundButton: ButtonStyle {
    var size: CGFloat = 44
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? AnyShapeStyle(Theme.onAmber) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .background(
                Circle().fill(prominent ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(.primary.opacity(configuration.isPressed ? 0.14 : 0.08)))
            )
            .brightness(prominent && configuration.isPressed ? -0.06 : 0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(Circle())
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// A small switch drawn in SwiftUI, so it renders the same in screenshots.
struct MiniSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Color(nsColor: .systemGreen) : Color.primary.opacity(0.14))
            .frame(width: 30, height: 18)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(.white).shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                    .frame(width: 14, height: 14).padding(2)
            }
            .animation(.easeOut(duration: 0.15), value: isOn)
            .contentShape(Capsule())
            .onTapGesture { isOn.toggle() }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct Progress: View {
    var fraction: Double
    var dimmed: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule().fill(dimmed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Theme.amber))
                    .frame(width: max(3, geo.size.width * fraction))
            }
        }
        .frame(height: 3)
        .animation(.linear(duration: 0.9), value: fraction)
    }
}
