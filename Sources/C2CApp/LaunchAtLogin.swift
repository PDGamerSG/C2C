import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLogin {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // The settings screen can be used again after the app is bundled and signed.
        }
    }
}
