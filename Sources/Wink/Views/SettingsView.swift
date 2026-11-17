import SwiftUI

final class SettingsState: ObservableObject {
    @Published var helperInstalled = false
    @Published var loginOn = false
}

struct SettingsView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject var prefs: Prefs
    var close: () -> Void
    @StateObject private var st = SettingsState()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { close() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("Settings").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, -6)
            .padding(.bottom, 14)

            row("Let it sleep on low battery", detail: "Below \(prefs.batteryThreshold)%, so a closed laptop in a bag doesn't drain flat.") {
                MiniSwitch(isOn: $prefs.batteryGuard)
            }
            if prefs.batteryGuard {
                HStack(spacing: 6) {
                    ForEach([10, 15, 20, 30], id: \.self) { v in
                        Button("\(v)%") { prefs.batteryThreshold = v }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: prefs.batteryThreshold == v ? .semibold : .regular))
                            .foregroundStyle(prefs.batteryThreshold == v ? AnyShapeStyle(Theme.onAmber) : AnyShapeStyle(.secondary))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(prefs.batteryThreshold == v ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(.primary.opacity(0.06))))
                    }
                }
                .padding(.bottom, 12)
            }
            row("Keep the display on too", detail: "Off by default. The screen can sleep while the Mac keeps working.") {
                MiniSwitch(isOn: Binding(get: { prefs.keepDisplayOn }, set: { prefs.keepDisplayOn = $0; session.applyPower() }))
            }
            row("Open at login", detail: nil) {
                MiniSwitch(isOn: Binding(get: { st.loginOn }, set: { prefs.openAtLogin = $0; st.loginOn = prefs.openAtLogin }))
            }

            Divider().padding(.vertical, 12)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lid-closed permission").font(.system(size: 13))
                    Text(st.helperInstalled ? "Set up. Wink can switch lid-closed sleep on and off." : "Not set up yet. Wink asks for your password once.")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(st.helperInstalled ? "Remove" : "Set up") {
                    if st.helperInstalled {
                        _ = session.power.uninstallLidHelper()
                        prefs.lidClosed = false
                    } else {
                        prefs.lidClosed = true
                        session.setUpLidClosed()
                    }
                    st.helperInstalled = session.power.lidHelperInstalled
                    session.applyPower()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.amber)
            }

            Divider().padding(.vertical, 12)

            HStack {
                Text("Wink \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
                Spacer()
                Button("GitHub") { NSWorkspace.shared.open(URL(string: "https://github.com/pavan-not-found/wink")!) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.leading, 12)
            }
        }
        .onAppear {
            st.helperInstalled = session.power.lidHelperInstalled
            st.loginOn = prefs.openAtLogin
        }
    }

    private func row<C: View>(_ title: String, detail: String?, @ViewBuilder control: () -> C) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let detail {
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control().padding(.top, 1)
        }
        .padding(.bottom, 12)
    }
}
