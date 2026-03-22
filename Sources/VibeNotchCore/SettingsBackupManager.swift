import Foundation

public enum SettingsBackupManager {

    // All known UserDefaults keys used by the app
    private static let allKeys: [String] = [
        // AppModel (YabaiBar.* prefix — legacy but still active)
        "YabaiBar.indicatorSurfaceMode",
        "YabaiBar.menuBarLabelMode",
        "YabaiBar.spaceIndicatorStyle",
        "YabaiBar.showAppNamesInMenu",
        "YabaiBar.maxAppsShownPerSpace",
        "YabaiBar.groupSpacesByDisplay",
        "YabaiBar.openNotchOnHover",
        "YabaiBar.minimumHoverDuration",
        "YabaiBar.enableHaptics",

        // ModuleRegistry (VibeNotch.* prefix)
        "VibeNotch.enabledModuleIDs",
        "VibeNotch.widgetOrder",
        "VibeNotch.leadingSlotOrder",
        "VibeNotch.trailingSlotOrder",
        "VibeNotch.disabledSlotIDs",
        "VibeNotch.activeStatusBarModuleID",

        // Jira module
        "Jira.selectedStatuses",
        "Jira.selectedProjects",
        "Jira.selectedTypes",
        "Jira.refreshInterval",

        // AI Quota module
        "AIQuota.monitorClaude",
        "AIQuota.monitorCodex",
        "AIQuota.refreshInterval",

        // TodoList module
        "TodoList.items",
        "TodoList.fontSize",
        "TodoList.showCompleted",
    ]

    // Dynamic key prefixes (collapse state, etc.)
    private static let dynamicPrefixes: [String] = [
        "Widget.collapsed.",
    ]

    private static var backupURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("VibeNotch", isDirectory: true)
            .appendingPathComponent("settings-backup.json", isDirectory: false)
    }

    // MARK: - Migration from old OpenNotch bundle

    /// Migrate settings from the old com.kevinbarfleur.OpenNotch plist.
    /// Maps `OpenNotch.*` keys → `VibeNotch.*` keys. All other keys are copied as-is.
    public static func migrateFromOldAppIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationFlag = "VibeNotch.migratedFromOpenNotch"
        guard !defaults.bool(forKey: migrationFlag) else { return }
        defer { defaults.set(true, forKey: migrationFlag) }

        guard let oldDefaults = UserDefaults(suiteName: "com.kevinbarfleur.OpenNotch") else { return }
        let oldDict = oldDefaults.dictionaryRepresentation()
        guard !oldDict.isEmpty else { return }

        var migrated = 0

        for key in allKeys {
            // Skip if the new domain already has a value
            if defaults.object(forKey: key) != nil { continue }

            // Try the key as-is from old domain
            if let value = oldDict[key] {
                defaults.set(value, forKey: key)
                migrated += 1
                continue
            }

            // Try mapping OpenNotch.* → VibeNotch.* (old domain used OpenNotch.*)
            if key.hasPrefix("VibeNotch.") {
                let oldKey = "OpenNotch." + key.dropFirst("VibeNotch.".count)
                if let value = oldDict[oldKey] {
                    defaults.set(value, forKey: key)
                    migrated += 1
                }
            }
        }

        // Migrate dynamic keys (Widget.collapsed.*)
        for (key, value) in oldDict {
            for prefix in dynamicPrefixes {
                if key.hasPrefix(prefix), defaults.object(forKey: key) == nil {
                    defaults.set(value, forKey: key)
                    migrated += 1
                }
            }
        }

        if migrated > 0 {
            NSLog("VibeNotch: migrated \(migrated) settings from OpenNotch")
        }
    }

    // MARK: - Backup

    /// Export all settings to the backup file.
    public static func exportBackup() {
        let defaults = UserDefaults.standard
        var dict: [String: Any] = [:]

        for key in allKeys {
            if let value = defaults.object(forKey: key) {
                dict[key] = jsonSafe(value)
            }
        }

        // Collect dynamic keys
        let allUserDefaults = defaults.dictionaryRepresentation()
        for (key, value) in allUserDefaults {
            for prefix in dynamicPrefixes {
                if key.hasPrefix(prefix) {
                    dict[key] = jsonSafe(value)
                }
            }
        }

        guard !dict.isEmpty else { return }

        // Filter out any values that JSONSerialization can't handle
        let safeDict = dict.filter { JSONSerialization.isValidJSONObject([$0.key: $0.value]) }

        do {
            let dir = backupURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: safeDict, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: backupURL, options: .atomic)
            NSLog("VibeNotch: exported \(safeDict.count) settings to backup")
        } catch {
            NSLog("VibeNotch: failed to export settings backup: \(error.localizedDescription)")
        }
    }

    /// Restore settings from the backup file. Only applies keys that are not already set.
    /// Returns true if any settings were restored.
    @discardableResult
    public static func restoreBackupIfNeeded() -> Bool {
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return false }

        // Only restore if we appear to have no settings (fresh install / new bundle ID)
        let defaults = UserDefaults.standard
        let hasExistingSettings = defaults.object(forKey: "YabaiBar.indicatorSurfaceMode") != nil
            || defaults.object(forKey: "VibeNotch.enabledModuleIDs") != nil

        guard !hasExistingSettings else { return false }

        return forceRestoreBackup()
    }

    /// Force restore all settings from backup, overwriting current values.
    @discardableResult
    public static func forceRestoreBackup() -> Bool {
        guard let data = try? Data(contentsOf: backupURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        let defaults = UserDefaults.standard
        var restored = 0

        for (key, value) in dict {
            defaults.set(fromJsonSafe(value), forKey: key)
            restored += 1
        }

        if restored > 0 {
            NSLog("VibeNotch: restored \(restored) settings from backup")
        }

        return restored > 0
    }

    /// Returns true if a backup file exists.
    public static var hasBackup: Bool {
        FileManager.default.fileExists(atPath: backupURL.path)
    }

    /// Returns the path to the backup file.
    public static var backupPath: String {
        backupURL.path
    }

    /// Returns the last modification date of the backup file, if it exists.
    public static var backupDate: Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: backupURL.path) else {
            return nil
        }
        return attrs[.modificationDate] as? Date
    }

    // MARK: - JSON-safe conversions

    /// Convert a UserDefaults value to something JSON-serializable.
    /// Data is stored as base64-encoded string with a prefix marker.
    private static func jsonSafe(_ value: Any) -> Any {
        if let data = value as? Data {
            return "__base64__" + data.base64EncodedString()
        }
        return value
    }

    /// Convert a JSON value back to the original type.
    private static func fromJsonSafe(_ value: Any) -> Any {
        if let str = value as? String, str.hasPrefix("__base64__") {
            let b64 = String(str.dropFirst("__base64__".count))
            if let data = Data(base64Encoded: b64) {
                return data
            }
        }
        return value
    }
}
