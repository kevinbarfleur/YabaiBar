import AppKit
import CoreGraphics

extension NSScreen {
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return nil
        }

        return CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
    }

    var menuBarHeight: CGFloat {
        frame.maxY - visibleFrame.maxY
    }

    var hasHardwareNotch: Bool {
        safeAreaInsets.top > 0 && auxiliaryTopLeftArea != nil && auxiliaryTopRightArea != nil
    }

    var resolvedNotchWidth: CGFloat {
        guard hasHardwareNotch,
              let leftAreaWidth = auxiliaryTopLeftArea?.width,
              let rightAreaWidth = auxiliaryTopRightArea?.width else {
            return 184
        }

        return max(160, frame.width - leftAreaWidth - rightAreaWidth + 4)
    }

    var resolvedNotchHeight: CGFloat {
        if hasHardwareNotch {
            return max(28, safeAreaInsets.top)
        }

        return max(28, menuBarHeight)
    }

    static func matchingDisplayUUID(_ uuid: String?) -> NSScreen? {
        guard let uuid else {
            return nil
        }

        return NSScreen.screens.first(where: { $0.displayUUID == uuid })
    }
}
