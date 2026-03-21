import Foundation

public enum YabaiIntegrationRenderer {
    public static let startMarker = "# >>> OpenNotch >>>"
    public static let endMarker = "# <<< OpenNotch <<<"
    public static let legacyStartMarker = "# >>> YabaiBar >>>"
    public static let legacyEndMarker = "# <<< YabaiBar <<<"

    public static let supportedEvents = [
        "space_changed",
        "window_focused",
        "window_created",
        "window_destroyed",
        "window_moved",
        "window_minimized",
        "window_deminimized",
        "application_terminated",
    ]

    public static func render(
        executablePath: String,
        runtimeDirectoryPath: String,
        yabaiExecutablePath: String
    ) -> String {
        let executable = shellQuote(executablePath)
        let runtimeDirectory = shellQuote(runtimeDirectoryPath)
        let yabaiExecutable = shellQuote(yabaiExecutablePath)

        let lines = supportedEvents.flatMap { event -> [String] in
            let label = signalLabel(for: event)
            let action = "YABAIBAR_RUNTIME_DIR=\(runtimeDirectory) YABAIBAR_YABAI_PATH=\(yabaiExecutable) \(executable) --signal \(event)"
            return [
                "yabai -m signal --remove \(label) >/dev/null 2>&1 || true",
                "yabai -m signal --add event=\(event) action=\(shellQuote(action)) label=\(label)",
            ]
        }

        return ([startMarker, "# Managed by OpenNotch. Changes inside this block will be replaced."]
            + lines
            + [endMarker, ""])
            .joined(separator: "\n")
    }

    public static func managedBlock(in contents: String) -> String? {
        guard let range = managedRange(in: contents) else {
            return nil
        }

        return String(contents[range])
    }

    public static func merge(managedBlock: String, into contents: String) -> String {
        if let range = managedRange(in: contents) {
            var updated = contents
            updated.replaceSubrange(range, with: managedBlock)
            return normalizedContents(updated)
        }

        let trimmed = normalizedContents(contents).trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return managedBlock
        }

        return "\(trimmed)\n\n\(managedBlock)"
    }

    public static func signalLabel(for event: String) -> String {
        "yabaibar-\(event.replacingOccurrences(of: "_", with: "-"))"
    }

    private static func managedRange(in contents: String) -> Range<String.Index>? {
        let resolvedStart: String.Index?
        let resolvedEndMarker: String

        if let newStart = contents.range(of: startMarker)?.lowerBound {
            resolvedStart = newStart
            resolvedEndMarker = endMarker
        } else if let legacyStart = contents.range(of: legacyStartMarker)?.lowerBound {
            resolvedStart = legacyStart
            resolvedEndMarker = legacyEndMarker
        } else {
            resolvedStart = nil
            resolvedEndMarker = endMarker
        }

        guard let start = resolvedStart else {
            return nil
        }

        guard let endMarkerRange = contents.range(of: resolvedEndMarker, range: start..<contents.endIndex) else {
            return nil
        }

        let end = contents[endMarkerRange.upperBound...]
            .prefix(while: { $0 == "\n" || $0 == "\r" })
            .endIndex

        return start..<end
    }

    private static func normalizedContents(_ contents: String) -> String {
        contents.replacingOccurrences(of: "\r\n", with: "\n")
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
