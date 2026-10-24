# Settings import — Specs

## Summary

An explicit General-settings action reads AltTab's persisted functional settings and offers a preview. No source preferences or Keychain entries are modified. Application version `1.0.0` and upstream-compatible preference format `11.10.1` are independent.

## Behavior

* Accept complete numeric 10.x/11.x source versions no newer than 11.10.1. Reject missing, malformed and unknown versions before migration.
* Pass only functional keys, their known legacy equivalents and the version to an isolated migration domain. Validate current-format values after migration, including enum bounds, flags, shortcut archives and exception JSON.
* Read only six remembered functional selections from the upstream auxiliary settings suite. Valid remembered indices override downgraded selections; invalid snapshots reject the import.
* Exclude licenses, identity, trial state, usage history, login startup, permission choices and network settings. Functional keys unset in the source are cleared in the destination so defaults apply.
* Confirm before applying. Save the exact previous destination domain to an atomic, private plist backup before the first preference write. A backup failure performs no writes. A persistence failure restores the previous domain; a rollback failure reports the backup path.
* Cancelled previews perform no application-setting writes. Successful imports invalidate both caches, apply language selection, and offer restart. A running AltTab process triggers a shortcut-conflict reminder.
* File-based settings restore uses the same validation and backup path.

## Tests

`PreferencesImportChecks` is shared by XCTest and `scripts/check_import.sh`. It exercises version boundaries, functional filtering, nine shortcuts, source immutability, invalid values, all remembered choices, migration ordering, backup contents/permissions, independent-key preservation, absent-key reset, persistence rollback and backup failure.

The AppKit preview, original-application conflict reminder and actual ShortcutRecorder migration are checked with the retained migration tests and the manual import scenarios in `docs/verification.md`.
