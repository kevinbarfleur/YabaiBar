import Foundation
import ServiceManagement

enum LoginItemState: Equatable {
    case unavailable(String)
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    var statusText: String {
        switch self {
        case let .unavailable(message):
            return message
        case .notRegistered:
            return "Launch at login is off"
        case .enabled:
            return "Launch at login is on"
        case .requiresApproval:
            return "Launch at login requires approval"
        case .notFound:
            return "Launch at login service not found"
        }
    }
}

@MainActor
final class LoginItemManager {
    func currentState(isEligibleForRegistration: Bool) -> LoginItemState {
        guard isEligibleForRegistration else {
            return .unavailable("Install the app in Applications first")
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .unavailable("Unknown login item state")
        }
    }

    func ensureEnabled(isEligibleForRegistration: Bool) -> LoginItemState {
        guard isEligibleForRegistration else {
            return .unavailable("Install the app in Applications first")
        }

        do {
            try SMAppService.mainApp.register()
        } catch {
            return .unavailable(error.localizedDescription)
        }

        return currentState(isEligibleForRegistration: isEligibleForRegistration)
    }

    func setEnabled(_ enabled: Bool, isEligibleForRegistration: Bool) -> LoginItemState {
        guard isEligibleForRegistration else {
            return .unavailable("Install the app in Applications first")
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            return .unavailable(error.localizedDescription)
        }

        return currentState(isEligibleForRegistration: isEligibleForRegistration)
    }
}
