import SwiftUI

final class PopoverUI: ObservableObject { @Published var showSettings = false }

struct PopoverView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var prefs: Prefs
    @StateObject private var ui = PopoverUI()

    var body: some View {
        VStack(spacing: 0) {
            if ui.showSettings {
                SettingsView(close: { ui.showSettings = false })
            } else {
                if session.externalSleepDisabled && session.mode == .off {
                    ExternalBanner()
                }
                if session.mode == .off {
                    SetupView()
                } else {
                    RunningView()
                }
                Footer(showSettings: $ui.showSettings)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .frame(width: 300)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { guard session.mode == .off else { return .ignored }; session.step(-1); return .handled }
        .onKeyPress(.rightArrow) { guard session.mode == .off else { return .ignored }; session.step(1); return .handled }
        .onKeyPress(.space) { session.toggle(); return .handled }
        .onKeyPress(.return) { if session.mode == .off { session.start(); return .handled }; return .ignored }
    }
}

// MARK: - Setup

struct SetupView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        let stop = session.selectedStop
        let hero = Fmt.hero(stop)
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(hero.big)
                    .font(.system(size: hero.unit == nil ? 40 : 52, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let unit = hero.unit {
                    Text(unit)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 56)
            .animation(.snappy(duration: 0.2), value: stop.id)

            Text(untilLine(stop))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            RulerView(stops: session.stops, selected: $session.selected)
                .padding(.horizontal, -18)
                .padding(.top, 14)

            Button("Keep awake") { session.start() }
                .buttonStyle(AmberButton())
                .padding(.top, 12)

            if let reason = session.lastStop {
                Text(stopMessage(reason))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 9)
            }
        }
    }

    private func untilLine(_ stop: DurationStop) -> AttributedString {
        guard let d = stop.resolvedDuration(now: session.now) else { return AttributedString("until you stop it") }
        var s = AttributedString("until ")
        var t = AttributedString(Fmt.until(session.now.addingTimeInterval(d), now: session.now))
        t.foregroundColor = .primary
        s.append(t)
        if stop.isMorning { s.append(AttributedString(" · \(Fmt.words(d))")) }
        return s
    }

    private func stopMessage(_ r: StopReason) -> String {
        switch r {
        case .finished: return "Time's up. Your Mac sleeps normally again."
        case .lowBattery: return "Stopped at low battery so your Mac could sleep."
        case .hot: return "Stopped because your Mac was running very hot."
        case .user: return ""
        }
    }
}

// MARK: - Running

struct RunningView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        let paused = session.mode == .paused
        let value = session.isForever ? session.elapsed : (session.remaining ?? 0)
        let c = Fmt.countdown(value)
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(c.main).font(.system(size: 52, weight: .semibold)).monospacedDigit()
                if let s = c.seconds {
                    Text(s).font(.system(size: 30, weight: .semibold)).monospacedDigit().foregroundStyle(.tertiary)
                }
            }
            .frame(height: 56)
            .opacity(paused ? 0.38 : 1)

            subline(paused: paused)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Progress(fraction: session.fraction, dimmed: paused)
                .padding(.horizontal, 6)
                .padding(.top, 18)

            HStack(spacing: 22) {
                if !session.isForever {
                    Button("+1h") { session.extend(by: 3600) }
                        .buttonStyle(RoundButton())
                        .help("Add an hour")
                }
                Button { session.toggle() } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill").font(.system(size: 20, weight: .bold))
                }
                .buttonStyle(RoundButton(size: 60, prominent: true))
                .help(paused ? "Resume" : "Pause, and let your Mac sleep")
                Button { session.stop() } label: {
                    Image(systemName: "stop.fill").font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(RoundButton())
                .help("Stop, and let your Mac sleep")
            }
            .padding(.top, 18)
        }
    }

    @ViewBuilder
    private func subline(paused: Bool) -> some View {
        if paused {
            Text("Paused. Your Mac can sleep until you resume.")
        } else if session.isForever {
            Text("Awake for \(Fmt.words(session.elapsed)) · until you stop it")
        } else if let end = session.endAt {
            Text("Awake until ") + Text(Fmt.until(end, now: session.now)).foregroundColor(.primary)
        }
    }
}

// MARK: - Footer

struct Footer: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var prefs: Prefs
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let notice = session.notice {
                Text(notice)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }
            Divider().padding(.top, 16)
            HStack(spacing: 10) {
                Text("Keep going with the lid closed")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                MiniSwitch(isOn: Binding(
                    get: { prefs.lidClosed },
                    set: { on in
                        prefs.lidClosed = on
                        if on { session.setUpLidClosed() }
                        session.applyPower()
                    }
                ))
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 13))
                }
                .buttonStyle(QuietButton())
                .help("Settings")
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - The "your Mac never sleeps" banner

struct ExternalBanner: View {
    @EnvironmentObject var session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your Mac is set to never sleep")
                .font(.system(size: 13, weight: .semibold))
            Text("Something ran pmset disablesleep, so it stays on with the lid shut, on battery, until someone turns it off. Let Wink handle it and it only stays up when you ask.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Turn normal sleep back on") { session.restoreNormalSleep() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.primary.opacity(0.06)))
        .padding(.top, -8)
        .padding(.bottom, 16)
    }
}
