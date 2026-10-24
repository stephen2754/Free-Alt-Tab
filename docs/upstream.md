# Upstream provenance and feature parity

Baseline: [lwouis/alt-tab-macos v11.10.1](https://github.com/lwouis/alt-tab-macos/releases/tag/v11.10.1), commit `c500294bdb01186011a5c64a412b04cef9931bef`, inspected on 2026-10-24.

Free-Alt-Tab preserves the upstream Git history and GPL-3.0 license. The `upstream` remote points to the original repository. Upstream tags remain local; the original `v1.0.0` tag is retained as `upstream/v1.0.0` to distinguish this fork's first release.

| Capability | Implementation |
|---|---|
| Window inventory, filtering, ordering and focus | Upstream event pipeline and state reducers |
| Thumbnails and selected-window preview | Upstream capture/cache code |
| Thumbnails, App Icons and Titles | Upstream styles, without preference degradation |
| Auto Size | Upstream sizing and tile layout |
| Search | Upstream ranking, Unicode matching, highlighting and editing state |
| Nine shortcuts and independent appearance | Upstream preferences, editors and actions, without slot gates |
| Release-to-focus, keep-open and search modes | Upstream shortcut behavior |
| Spaces, displays, gestures and exceptions | Upstream implementations |
| CLI and accessibility | Upstream interfaces under an independent application identity |
| AltTab settings import | New isolated migration, validation, backup and rollback flow |

## Fork changes

Changes begin on 2026-10-24. The fork removes licensing, Keychain activation, device fingerprinting, trial clocks, promotional scheduling, purchase UI, trial discovery hints and their exclusive tests/resources. Functional search and shortcuts remain. Shared segmented-control spacing is retained alongside the settings controls.

The application is renamed, uses `io.github.stephen2754.free-alt-tab`, and targets arm64/macOS 26+. Settings format versioning remains at `11.10.1`, independently of application version `1.0.0`. The obsolete pre-ScreenCaptureKit permission fallback is excluded from this target.

Sparkle and AppCenter, their packages and release/deployment hooks are removed. Updates and feedback open project pages only after a user action. Local diagnostics and About usage counts are retained.

## Maintenance

Bring upstream changes onto a separate integration branch, record the exact source commit, and review the functional diff before merging. Preserve the feature-based directory structure, programmatic AppKit UI, compact Swift style, specifications and regression tests. No reverse engineering or changes to official application binaries were used for this baseline.

Future upstream releases are not automatically imported or promised. New closed-source capabilities, if any, require a separate behavior specification and implementation assessment.
