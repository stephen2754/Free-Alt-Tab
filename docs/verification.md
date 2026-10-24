# Verification and known limitations

## Source release

The baseline is AltTab 11.10.1. Free-Alt-Tab targets Apple silicon and macOS 26+. The first release is source-only; local self-signing is documented separately from Developer ID distribution.

Local implementation checks run on an arm64 Mac with macOS 26.6.2 and Command Line Tools. They cover project references, all Swift syntax, import transaction scenarios, localization catalogs and generated native artwork. Full Xcode builds and retained XCTest coverage are checked by CI on macOS 26 and 27; the current run status is available under the repository's Actions tab.

CI compilation is not a claim that all desktop interactions below have been exercised. Hardware-dependent behavior and performance measurements require a signed build on the target desktop.

## Automated results — 2026-10-24

Tested application/test sources: `1082c649e9fd69802e336225057402b86f78daa0`.
The release adds only this verification record after that commit.

[Successful CI run](https://github.com/stephen2754/Free-Alt-Tab/actions/runs/40103689212)

| Environment | Debug | Release | XCTest |
|---|---|---|---|
| macOS 26 / Xcode 26.6 / arm64 | Passed | Passed | 1,363 tests, 0 failures |
| macOS 27 / Xcode 27.1 / arm64 | Passed | Passed | 1,363 tests, 0 failures |

Both CI jobs also passed project-reference validation, native localization extraction and format checks
for 21 languages, generated-artwork verification, six illustration compiler tests, and the shared import
safety checks. Locally, the import runner passed 38 assertions; Debug/Release Swift type checking passed
with warnings treated as errors. Full local Xcode commands were attempted but could not run with Command
Line Tools alone; the successful application builds and XCTest results above are from CI.

The 250 ms compile-time diagnostics remain enabled. CI bounds build concurrency to reduce shared-runner
contention. A retained artwork test uses permission artwork for RTL changes and verifies that artwork
without theme overrides remains unchanged between appearances.

## Manual acceptance matrix

Record OS version, hardware, build commit, signing identity and actual result for each run. Until a result is recorded, these scenarios remain unverified for this fork.

| Area | Scenarios |
|---|---|
| Switching | Fast tap/release, held cycling, backward navigation, repeat timing, close last window |
| Styles | Thumbnails/App Icons/Titles, Auto Size, different screen sizes, many and zero windows |
| Search | Application/title matching, Unicode, Chinese IME composition, ranking/highlights, Escape/Return, copy/paste |
| Shortcuts | All nine slots, independent filters/appearance, modifier-only and system-replacement shortcuts |
| Window state | Hidden/minimized/full-screen windows, merged tabs, window/app creation and destruction |
| Desktop | Multiple displays/Spaces, display reconnect, full-screen transitions, Stage Manager, sleep/wake |
| Permissions | Fresh grant, denied/revoked Accessibility, skipped/restored Screen Recording, signed rebuild |
| Import | AltTab 10.x shortcut storage, 11.x settings, remembered selections, cancel, invalid/future versions, backup restore |
| Coexistence | Original settings unchanged, independent CLI/login item, running-source conflict reminder |
| Accessibility | VoiceOver, sticky keys, reduced motion/transparency, light/dark and right-to-left UI |
| Network | No startup/switch/search connections; only user-requested project pages open |
| Performance | Same-Mac baseline/fork latency, search response, idle CPU, memory and wake behavior |

## Known limitations

* Stage Manager can distort or shrink thumbnails, as in upstream. App Icons and Titles provide alternative styles.
* Private macOS APIs remain necessary for window/Space handling and can change in future OS releases. No Mac App Store compatibility is claimed.
* A new application identity requires fresh macOS permissions. Stable local signing prevents repeated identity changes; it does not transfer AltTab's grants.
* Simultaneously running both switchers with the same shortcuts can cause conflicts. Import does not quit or reconfigure the original app.
* New import messages use English fallback outside English and Simplified Chinese; existing upstream translations remain.
* No signed/notarized downloads or automatic binary installation are provided. Update checks open this project's source-release page.
* No performance improvement over upstream is claimed without same-machine measurements.
