import Foundation

/// Shared safety scenarios run under XCTest and the command-line Swift compiler. The latter
/// keeps import transactions testable on machines with Command Line Tools but no Xcode.
enum PreferencesImportChecks {
    struct Failure: Error, CustomStringConvertible { let description: String }
    private static var checks = 0
    private static let rules: [String: PreferenceImportRule] = [
        "appearanceStyle": .index(3), "appearanceSize": .index(4), "shortcutStyle": .index(3),
        "appearanceStyleOverride": .index(3), "appearanceSizeOverride": .index(4),
        "shortcutStyleOverride": .index(3),
        "shortcutCount": .integer(1 ... 9), "mouseHoverEnabled": .flag,
    ]

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1
        if !condition() {
            throw Failure(description: message)
        }
    }

    private static func rejects(_ body: () throws -> Void) throws {
        checks += 1
        do { try body() } catch is PreferencesImportError { return }
        throw Failure(description: "Expected a settings validation error")
    }

    private static func prepare(_ source: [String: Any],
                                remembered: [String: Any] = [:]) throws -> PreferencesImportPlan {
        try PreferencesImport.prepare(
            source: source,
            remembered: remembered,
            rules: rules,
            migrate: { values, _ in values }
        )
    }

    @discardableResult
    static func run() throws -> Int {
        checks = 0
        try require(PreferencesFormat.supports("10.0.0"), "AltTab 10 must be supported")
        try require(PreferencesFormat.supports("11.10.1"), "Baseline format must be supported")
        for version in ["", "1.0.0", "9.99.0", "11.10.2", "11.9.9999.1", "12.0.0", "11.0", "#VERSION#"] {
            try require(!PreferencesFormat.supports(version), "Unexpected supported version: \(version)")
        }
        try rejects { _ = try prepare(["appearanceStyle": "1"]) }
        let original: [String: Any] = [
            "preferencesVersion": "11.10.1",
            "appearanceStyle": "2",
            "shortcutCount": "9",
            "startAtLogin": "true",
            "licenseKey": "do-not-import",
            "email": "private@example.invalid",
            "trialStartDate": 123,
        ]
        let pristine = try PropertyListSerialization.data(
            fromPropertyList: original,
            format: .binary,
            options: 0
        )
        let plan = try prepare(original)
        try require(
            plan.values.count == 2 && plan.values["shortcutCount"] as? String == "9",
            "Nine shortcut slots must survive import"
        )
        try require(
            plan.ignoredKeys.count == 4 && plan.values["licenseKey"] == nil,
            "Nonfunctional state must be excluded"
        )
        let after = try PropertyListSerialization.data(
            fromPropertyList: original,
            format: .binary,
            options: 0
        )
        try require(pristine == after, "Preparing an import must not mutate its source")
        for source: [String: Any] in [
            ["preferencesVersion": "11.10.1", "appearanceStyle": "3"],
            ["preferencesVersion": "11.10.1", "appearanceStyle": -1],
            ["preferencesVersion": "11.10.1", "shortcutCount": "0"],
            ["preferencesVersion": "11.10.1", "shortcutCount": "10"],
            ["preferencesVersion": "11.10.1", "mouseHoverEnabled": "yes"],
        ] { try rejects { _ = try prepare(source) } }
        try rejects { _ = try prepare(["preferencesVersion": "11.10.1", "licenseKey": "excluded"]) }
        let remembered = ["rememberedAppearanceStyle": 1, "rememberedAppearanceSize": 3,
                          "rememberedShortcutStyle": 2, "rememberedAppearanceStyleOverride": 2,
                          "rememberedAppearanceSizeOverride": 3, "rememberedShortcutStyleOverride": 2]
        let restored = try prepare(
            ["preferencesVersion": "11.10.1", "appearanceStyle": "0"],
            remembered: remembered
        )
        try require(restored.restoredKeys.count == 6, "All remembered functional selections must be restored")
        try require(
            restored.values["appearanceStyle"] as? String == "1",
            "Remembered style must win over downgraded style"
        )
        for bad: Any in [99, -1, true, 1.5, "1"] {
            try rejects { _ = try prepare(original, remembered: ["rememberedAppearanceStyle": bad]) }
        }
        var migratedVersion: String?
        let migrated = try PreferencesImport.prepare(
            source: ["preferencesVersion": "10.3.0", "oldStyle": "2", "licenseKey": "excluded"],
            rules: rules,
            legacyKeys: ["oldStyle"],
            migrate: { values, version in
                migratedVersion = version
                try require(
                    values["licenseKey"] == nil,
                    "Migration must receive only allowed settings"
                )
                return ["appearanceStyle": values["oldStyle"]!]
            }
        )
        try require(
            migratedVersion == "10.3.0" && migrated.values["appearanceStyle"] as? String == "2",
            "Migration must precede validation"
        )
        try transactions(plan)
        return checks
    }

    private static func transactions(_ plan: PreferencesImportPlan) throws {
        let domain = "io.github.stephen2754.free-alt-tab.tests.import." + UUID().uuidString
        let defaults = UserDefaults(suiteName: domain)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: domain)
            try? FileManager.default.removeItem(at: directory)
        }
        let previous = [
            "startAtLogin": "false",
            "appearanceStyle": "0",
            "localOnly": "preserved",
            "mouseHoverEnabled": "true",
        ]
        defaults.setPersistentDomain(previous, forName: domain)
        let backup = try PreferencesImport.apply(
            plan,
            defaults: defaults,
            domain: domain,
            backupDirectory: directory
        )
        let backedUp = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: backup),
            format: nil
        ) as? [String: String]
        try require(backedUp == previous, "Backup must contain the exact previous domain")
        let imported = defaults.persistentDomain(forName: domain)!
        try require(imported["appearanceStyle"] as? String == "2", "Functional choices must be applied")
        try require(
            imported["startAtLogin"] as? String == "false" && imported["localOnly"] as? String == "preserved",
            "Independent preferences must survive"
        )
        try require(
            imported["mouseHoverEnabled"] == nil,
            "An unset source preference must reset a previous functional choice"
        )
        try require(
            imported["preferencesVersion"] as? String == PreferencesFormat.current,
            "App 1.0.0 must use the upstream format version"
        )
        let permissions =
            try FileManager.default.attributesOfItem(atPath: backup.path)[.posixPermissions] as? NSNumber
        try require(permissions?.intValue == 0o600, "Settings backups must be private")
        defaults.setPersistentDomain(previous, forName: domain)
        var writes = [[String: Any]]()
        try rejects {
            try PreferencesImport.apply(
                plan,
                defaults: defaults,
                domain: domain,
                backupDirectory: directory,
                persist: { values in
                    writes.append(values)
                    return writes.count == 2
                }
            )
        }
        try require(
            writes.count == 2 && writes.last?["appearanceStyle"] as? String == "0",
            "A failed save must roll back"
        )
        let blockingFile = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: blockingFile)
        var attempted = false
        do {
            try PreferencesImport.apply(
                plan,
                defaults: defaults,
                domain: domain,
                backupDirectory: blockingFile,
                persist: { _ in attempted = true; return true }
            )
            throw Failure(description: "An unavailable backup destination must fail")
        } catch is Failure {
            throw Failure(description: "An unavailable backup destination unexpectedly succeeded")
        } catch { try require(!attempted, "Backup failure must prevent all preference writes") }
    }
}

#if canImport(XCTest)
    import XCTest

    final class PreferencesImportTests: XCTestCase {
        func testImportValidationRestorationAndTransactions() throws {
            try PreferencesImportChecks.run()
        }
    }
#endif
