import AppKit
import SwiftUI

/// A horizontal tick ruler. Drag it, scroll it with the trackpad, or click a label.
/// Every snap gives a light haptic tick on Force Touch trackpads.
final class RulerState: ObservableObject {
    @Published var pos: CGFloat = 0
    var dragOrigin: CGFloat?
    var monitor: Any?
    var wheelSettle: DispatchWorkItem?
}

struct RulerView: View {
    let stops: [DurationStop]
    @Binding var selected: Int

    @StateObject private var st = RulerState()

    private let gap: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            ZStack(alignment: .topLeading) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                    let x = mid + (CGFloat(i) - st.pos) * gap
                    let isSel = i == selected
                    Capsule()
                        .fill(isSel ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(.secondary))
                        .frame(width: 1.5, height: 18)
                        .position(x: x, y: 13)
                    if i < stops.count - 1 {
                        ForEach(1..<4, id: \.self) { k in
                            Capsule().fill(.tertiary)
                                .frame(width: 1.5, height: 10)
                                .position(x: x + CGFloat(k) * gap / 4, y: 13)
                        }
                    }
                    Text(stop.label)
                        .font(.system(size: 11, weight: isSel ? .semibold : .regular))
                        .foregroundStyle(isSel ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .fixedSize()
                        .position(x: x, y: 40)
                        .onTapGesture { snap(to: i) }
                }
                Capsule().fill(Theme.amber)
                    .frame(width: 3, height: 26)
                    .position(x: mid, y: 13)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        if st.dragOrigin == nil { st.dragOrigin = st.pos }
                        move(to: (st.dragOrigin ?? st.pos) - v.translation.width / gap)
                    }
                    .onEnded { _ in
                        st.dragOrigin = nil
                        snap(to: Int(st.pos.rounded()))
                    }
            )
        }
        .frame(height: 56)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0), .init(color: .black, location: 0.22),
                .init(color: .black, location: 0.78), .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
        )
        .onAppear {
            st.pos = CGFloat(selected)
            st.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { e in
                let d = abs(e.scrollingDeltaX) > abs(e.scrollingDeltaY) ? e.scrollingDeltaX : e.scrollingDeltaY
                let k: CGFloat = e.hasPreciseScrollingDeltas ? 0.6 : 8
                move(to: st.pos - d * k / gap)
                st.wheelSettle?.cancel()
                let work = DispatchWorkItem { snap(to: Int(st.pos.rounded())) }
                st.wheelSettle = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: work)
                return nil
            }
        }
        .onDisappear {
            if let m = st.monitor { NSEvent.removeMonitor(m) }
            st.monitor = nil
        }
        .onChange(of: selected) { _, new in
            if Int(st.pos.rounded()) != new { withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { st.pos = CGFloat(new) } }
        }
        .accessibilityElement()
        .accessibilityLabel("Duration")
        .accessibilityValue(stops[selected].label)
        .accessibilityAdjustableAction { dir in
            snap(to: selected + (dir == .increment ? 1 : -1))
        }
    }

    private func move(to p: CGFloat) {
        st.pos = min(max(-0.4, p), CGFloat(stops.count - 1) + 0.4)
        let i = min(max(0, Int(st.pos.rounded())), stops.count - 1)
        if i != selected {
            selected = i
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func snap(to i: Int) {
        let i = min(max(0, i), stops.count - 1)
        if i != selected { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        selected = i
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { st.pos = CGFloat(i) }
    }
}
