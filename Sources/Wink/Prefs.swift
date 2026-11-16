import Foundation
import ServiceManagement

/// User preferences, backed by UserDefaults.
final class Prefs: ObservableObject {
    private let d: UserDefaults

    @Published var lidClosed: Bool { didSet { d.set(lidClosed, forKey: "lidClosed") } }
    @Published var batteryGuard: Bool { didSet { d.set(batteryGuard, forKey: "batteryGuard") } }
    @Published var batteryThreshold: Int { didSet { d.set(batteryThreshold, forKey: "batteryThreshold") } }
    @Published var keepDisplayOn: Bool { didSet { d.set(keepDisplayOn, forKey: "keepDisplayOn") } }
    @Published var lastStopID: String { didSet { d.set(lastStopID, forKey: "lastStopID") } }

    init(defaults: UserDefaults = .standard) {
        d = defaults
        d.register(defaults: [
            "lidClosed": true,
            "batteryGuard": true,
            "batteryThreshold": 15,
            "keepDisplayOn": false,
            "lastStopID": "2h",
        ])
        lidClosed = d.bool(forKey: "lidClosed")
        batteryGuard = d.bool(forKey: "batteryGuard")
        batteryThreshold = d.integer(forKey: "batteryThreshold")
        keepDisplayOn = d.bool(forKey: "keepDisplayOn")
        lastStopID = d.string(forKey: "lastStopID") ?? "2h"
    }

    var openAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Wink: login item change failed: \(error.localizedDescription)")
            }
        }
    }
}
