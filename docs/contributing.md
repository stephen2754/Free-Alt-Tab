# Contributing

Free-Alt-Tab is based on AltTab by Louis Pontoise and contributors. Contributions follow the GPL-3.0 license and the existing conventions in [AGENTS.md](../AGENTS.md).

## Architecture

The application uses Swift and programmatic AppKit, with no Interface Builder or SwiftUI. Files are grouped by feature:

| Directory | Responsibility |
|---|---|
| `src/switcher/` | Switcher UI, state, appearance, search and shortcuts |
| `src/windowserver/` and `src/window-tracking/` | WindowServer and accessibility event pipelines |
| `src/events/` | Keyboard, pointer, capture and system events |
| `src/macos/` | Permissions, login items and system API wrappers |
| `src/preferences/` | Settings, migrations and import transactions |
| `src/secondary-windows/` and `src/kit/` | Supporting windows and reusable AppKit views |
| `src/debug/` | Local QA, profiling and diagnostics |
| `vendor/ShortcutRecorder/` | Vendored shortcut recording dependency |

Keep low-latency work ahead of bookkeeping. Use observer APIs, caches and the existing AX/CGS/process schedulers. AppKit responder and window operations stay on the main thread. Do not replace the window-tracking implementation as part of unrelated UI changes.

For nontrivial behavior, keep implementation, `*Specs.md` and `*Tests.swift` together. Comments explain OS behavior, invariants and measured constraints; avoid narrating obvious code or obsolete history. Write code, comments and technical documentation in English and retain existing localizations.

## Validation

See [Building and testing](building.md). Run `ai/build.sh` and `ai/test.sh`, plus checks relevant to the change. Tests use isolated settings suites; do not modify real AltTab settings or request production permissions from unit tests.

Manual checks cover full-screen windows, multiple Spaces/displays, hidden/minimized windows, window creation/destruction, merged tabs, input methods, accessibility, gestures, sleep/wake and permission changes. Record actual OS/hardware and results in the verification notes.

The app uses private macOS APIs, documented beside their wrappers. They can change between OS releases; this architecture is intended for direct distribution rather than the Mac App Store.

Use conventional commit messages describing the resulting behavior. Preserve upstream attribution, source provenance and third-party license notices. This source-only release has no publishing backend or automated application deployment.
