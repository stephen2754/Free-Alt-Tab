import Cocoa
import ShortcutRecorder

/// Reads upstream preferences only on request. Migration uses a disposable domain, so
/// previews and cancelled imports never write to either application's real settings.
enum AltTabSettingsImport {
    static let sourceDomain = "com.lwouis.alt-tab-macos"
    private static let excludedKeys: Set<String> = [
        "startAtLogin", "screenRecordingPermissionSkipped", "settingsWindowShownOnFirstLaunch",
    ]

    static func show() {
        let source = UserDefaults.standard.persistentDomain(forName: sourceDomain) ?? [:]
        let store = UserDefaults(suiteName: sourceDomain + ".license")
        let remembered = PreferencesImport.rememberedKeys.keys.reduce(into: [String: Any]()) { values, key in
            values[key] = store?.object(forKey: "proTransition." + key)
        }
        show(source: source, remembered: remembered, fromAltTab: true)
    }

    static func show(source: [String: Any], remembered: [String: Any], fromAltTab _: Bool) {
        do {
            let plan = try prepare(source: source, remembered: remembered)
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Import settings?", comment: "Settings import confirmation")
            let details = String(
                format: NSLocalizedString(
                    "Version %@: %d settings, %d restored selections, %d excluded entries. Your current settings will be backed up before importing.",
                    comment: "Settings import summary"
                ),
                plan.sourceVersion,
                plan.values.count,
                plan.restoredKeys.count,
                plan.ignoredKeys.count
            )
            let running = isAltTabRunning
            alert.informativeText = details + "\n\n" + NSLocalizedString(
                "Functional settings absent from the source will return to defaults. Login and network settings remain independent.",
                comment: "Settings import summary"
            ) + (running
                ? "\n\n" + NSLocalizedString(
                    "AltTab is running. Quit it before restarting Free-Alt-Tab to avoid conflicting shortcuts.",
                    comment: "Settings import conflict"
                )
                : "")
            alert.addButton(withTitle: NSLocalizedString("Import", comment: "Settings import confirmation"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.present(attachedTo: SettingsWindow.shared) { response in
                guard response == .alertFirstButtonReturn else { return }
                commit(plan)
            }
        } catch { showError(error) }
    }

    static func prepare(source: [String: Any], remembered: [String: Any]) throws -> PreferencesImportPlan {
        try PreferencesImport.prepare(source: source, remembered: remembered, rules: rules,
                                      legacyKeys: ["blacklist"], migrate: migrate)
    }

    /// The same key and enum declarations used by the UI supply the import bounds.
    private static var rules: [String: PreferenceImportRule] {
        var result = [String: PreferenceImportRule]()
        for (key, value) in Preferences.defaultValues where !excludedKeys.contains(key) {
            if let text = value as? String, text == "true" || text == "false" {
                result[key] = .flag
            }
            if value is [String: Any] {
                result[key] = .custom { Preferences.decodeShortcutStorage($0).0 }
            }
        }
        result["shortcutCount"] = .integer(Preferences.minShortcutCount ... Preferences.maxShortcutCount)
        result["windowDisplayDelay"] = .integer(0 ... 900)
        result["exceptions"] = .custom { value in
            guard let text = value as? String, let data = text.data(using: .utf8) else { return false }
            return (try? JSONDecoder().decode([ExceptionEntry].self, from: data)) != nil
        }
        let globalCounts: [String: Int] = [
            "nextWindowGesture": GesturePreference.allCases.count,
            "cursorFollowFocus": CursorFollowFocus.allCases.count,
            "appearanceStyle": AppearanceStylePreference.allCases.count,
            "appearanceSize": AppearanceSizePreference.allCases.count,
            "appearanceTheme": AppearanceThemePreference.allCases.count,
            "showOnScreen": ShowOnScreenPreference.allCases.count,
            "titleTruncation": TitleTruncationPreference.allCases.count,
            "showTitles": ShowTitlesPreference.allCases.count,
            "menubarIcon": MenubarIconPreference.allCases.count,
            "language": LanguagePreference.allCases.count,
        ]
        for (key, count) in globalCounts { result[key] = .index(count) }
        let indexedCounts: [String: Int] = [
            "appsToShow": AppsToShowPreference.allCases.count,
            "spacesToShow": SpacesToShowPreference.allCases.count,
            "screensToShow": ScreensToShowPreference.allCases.count,
            "showMinimizedWindows": ShowHowPreference.allCases.count,
            "showHiddenWindows": ShowHowPreference.allCases.count,
            "showFullscreenWindows": ShowHowPreference.allCases.count,
            "showWindowlessApps": ShowHowPreference.allCases.count,
            "windowOrder": WindowOrderPreference.allCases.count,
            "shortcutStyle": ShortcutStylePreference.allCases.count,
            "showAppsOrWindows": GroupAppsPreference.allCases.count,
            "showTabsAsWindows": GroupTabsPreference.allCases.count,
            "appearanceStyleOverride": AppearanceStylePreference.allCases.count,
            "appearanceSizeOverride": AppearanceSizePreference.allCases.count,
            "appearanceThemeOverride": AppearanceThemePreference.allCases.count,
            "shortcutStyleOverride": ShortcutStylePreference.allCases.count,
        ]
        for index in 0 ... Preferences.maxShortcutCount {
            for (key, count) in indexedCounts { result[Preferences.indexToName(key, index)] = .index(count) }
        }
        return result
    }

    private static func migrate(_ values: [String: Any], _ version: String) throws -> [String: Any] {
        let domain = App.bundleIdentifier + ".import." + UUID().uuidString
        guard let temporary = UserDefaults(suiteName: domain)
        else { throw PreferencesImportError.persistence }
        let previous = PreferencesMigrations.defaults
        defer {
            PreferencesMigrations.defaults = previous
            temporary.removePersistentDomain(forName: domain)
        }
        temporary.setPersistentDomain(values, forName: domain)
        PreferencesMigrations.defaults = temporary
        PreferencesMigrations.removeCorruptedPreferences()
        PreferencesMigrations.updateToNewPreferences(version)
        return temporary.persistentDomain(forName: domain) ?? [:]
    }

    private static var isAltTabRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == sourceDomain }
    }

    private static func commit(_ plan: PreferencesImportPlan) {
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent(App.bundleIdentifier + "/Settings Backups")
            let backup = try PreferencesImport.apply(plan, defaults: .standard, domain: App.bundleIdentifier,
                                                     backupDirectory: directory)
            CachedUserDefaults.cache.withLock { $0.removeAll() }
            Preferences.invalidateAllCache()
            Preferences.language.applyToAppleLanguages()
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Settings imported", comment: "")
            alert.informativeText = NSLocalizedString(
                "The application needs to restart to apply the imported settings.",
                comment: ""
            ) + "\n\n" + backup.path
            alert.addButton(withTitle: NSLocalizedString("Restart Now", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
            alert.present(attachedTo: SettingsWindow.shared) { response in
                if response == .alertFirstButtonReturn {
                    App.restart()
                }
            }
        } catch { showError(error) }
    }

    private static func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("Failed to import settings", comment: "")
        alert.informativeText = error.localizedDescription
        alert.present(attachedTo: SettingsWindow.shared) { _ in }
    }
}
