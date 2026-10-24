import CoreFoundation
import Foundation

/// The upstream preference format evolves independently from this fork's application version.
enum PreferencesFormat {
    static let current = "11.10.1"

    static func supports(_ version: String) -> Bool {
        version.range(of: "^(10|11)\\.[0-9]+\\.[0-9]+$", options: .regularExpression) != nil
            && version.compare(current, options: .numeric) != .orderedDescending
    }
}

enum PreferenceImportRule {
    case flag
    case index(Int)
    case integer(ClosedRange<Int>)
    case custom((Any) -> Bool)

    func accepts(_ value: Any) -> Bool {
        switch self {
        case .flag: return (value as? String).map { $0 == "true" || $0 == "false" } ?? false
        case let .index(count):
            guard let text = value as? String, let index = Int(text) else { return false }
            return (0 ..< count).contains(index)
        case let .integer(range):
            guard let text = value as? String, let number = Int(text) else { return false }
            return range.contains(number)
        case let .custom(validate): return validate(value)
        }
    }
}

struct PreferencesImportPlan {
    let sourceVersion: String
    let values: [String: Any]
    let restoredKeys: [String]
    let ignoredKeys: [String]
    let clearedKeys: Set<String>
}

enum PreferencesImportError: LocalizedError {
    case unsupportedVersion
    case invalidValue(String)
    case empty
    case persistence
    case rollback(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return NSLocalizedString(
                "This settings version is missing or unsupported. Import AltTab 10.x or 11.x settings up to 11.10.1.",
                comment: "Settings import error"
            )
        case let .invalidValue(key): return String(
                format: NSLocalizedString(
                    "The settings contain an invalid value for %@. No settings were imported.",
                    comment: "Settings import error"
                ),
                key
            )
        case .empty: return NSLocalizedString(
                "No supported settings were found.",
                comment: "Settings import error"
            )
        case .persistence: return NSLocalizedString(
                "The imported settings could not be saved. Your previous settings were restored.",
                comment: "Settings import error"
            )
        case let .rollback(backup): return NSLocalizedString(
                "The settings could not be saved or restored. Restore the backup before restarting the application.",
                comment: "Settings import error"
            ) + "\n\n" + backup.path
        }
    }
}

enum PreferencesImport {
    /// These are functional selections saved when upstream downgrades preferences. No other
    /// entries from the upstream license suite are requested or passed to the importer.
    static let rememberedKeys = [
        "rememberedAppearanceStyle": "appearanceStyle",
        "rememberedAppearanceSize": "appearanceSize",
        "rememberedShortcutStyle": "shortcutStyle",
        "rememberedAppearanceStyleOverride": "appearanceStyleOverride",
        "rememberedAppearanceSizeOverride": "appearanceSizeOverride",
        "rememberedShortcutStyleOverride": "shortcutStyleOverride",
    ]

    static func prepare(source: [String: Any], remembered: [String: Any] = [:],
                        rules: [String: PreferenceImportRule], legacyKeys: Set<String> = [],
                        migrate: ([String: Any], String) throws -> [String: Any]) throws
        -> PreferencesImportPlan {
        guard let version = source["preferencesVersion"] as? String,
              PreferencesFormat.supports(version) else {
            throw PreferencesImportError.unsupportedVersion
        }
        let allowed = Set(rules.keys).union(legacyKeys).union(["preferencesVersion"])
        let filtered = source.filter { allowed.contains($0.key) }
        var migrated = try migrate(filtered, version)
        var restored = [String]()
        for (rememberedKey, key) in rememberedKeys {
            guard let raw = remembered[rememberedKey] else { continue }
            guard let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue.isFinite, number.doubleValue == Double(number.intValue),
                  let rule = rules[key], rule.accepts(number.stringValue) else {
                throw PreferencesImportError.invalidValue(key)
            }
            migrated[key] = number.stringValue
            restored.append(key)
        }
        var values = [String: Any]()
        for (key, value) in migrated {
            guard let rule = rules[key] else { continue }
            guard rule.accepts(value) else { throw PreferencesImportError.invalidValue(key) }
            values[key] = value
        }
        guard !values.isEmpty else { throw PreferencesImportError.empty }
        return PreferencesImportPlan(sourceVersion: version, values: values,
                                     restoredKeys: restored.sorted(),
                                     ignoredKeys: source.keys.filter { !allowed.contains($0) }.sorted(),
                                     clearedKeys: Set(rules.keys).subtracting(values.keys))
    }

    /// Back up before the first write. A failed write rolls back the exact previous domain;
    /// callers invalidate preference caches only after this transaction succeeds.
    @discardableResult
    static func apply(_ plan: PreferencesImportPlan, defaults: UserDefaults, domain: String,
                      backupDirectory: URL, persist: (([String: Any]) -> Bool)? = nil) throws -> URL {
        let previous = defaults.persistentDomain(forName: domain) ?? [:]
        let backup = try writeBackup(previous, directory: backupDirectory)
        var merged = previous.filter { !plan.clearedKeys.contains($0.key)
        }.merging(plan.values) { _, imported in imported }
        merged["preferencesVersion"] = PreferencesFormat.current
        let save: ([String: Any]) -> Bool = persist ?? { values in
            defaults.setPersistentDomain(values, forName: domain)
            return defaults.synchronize()
        }
        guard save(merged) else {
            guard save(previous) else { throw PreferencesImportError.rollback(backup) }
            throw PreferencesImportError.persistence
        }
        return backup
    }

    static func writeBackup(_ values: [String: Any], directory: URL) throws -> URL {
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent("settings-\(UUID().uuidString).plist")
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url
    }
}
