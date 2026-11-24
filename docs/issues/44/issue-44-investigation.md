# DockAltTab issue #44 — investigation report

**Date:** 2026-11-24 UTC. **Verdict:** reproduced. The blanking is an OS-level macOS 27.2.1 interaction with ScreenCaptureKit, not a DockAltTab event-handling bug. A single one-shot window capture of a system alert/confirmation surface is sufficient. No third-party utility is required. No DockAltTab source change was made.

## 1. Environment and baseline

- VM reached via `ssh -J house super@192.168.64.99`, macOS **27.2.1 (26B131)**, Darwin 27.2.0, VirtualMac2,1 (virtual Apple M1), 8 GB. Host: macOS 26.7.3, UTM/Apple Virtualization.
- Initial `/Applications`: DockAltTab, Safari, Utilities only. No suspected reporter utilities or third-party launch agents/daemons. DockAltTab was not running.
- DockAltTab was **4.00.2 (40002)**, matching the GitHub v4.00.2 release. SHA-256 of both local copies and the downloaded release:
  `f876fbb08e7119f0a07d52a4328ed23b6755d7fb8246f6e596b8b29a48235fdf`
  Developer ID `L33QBJT48B`, notarization ticket stapled.
- Preferences showed a prior launch but no capture/skip settings; source default `captureWindowsInBackground=true`.
- User then granted **Accessibility only** and selected **Use the app without this permission** for Screen Recording. App logs independently confirmed `accessibility:granted screenRecording:skipped`.
- The host could not take screenshots (`could not create image from display`); UTM CLI returned Apple Events error -1743. To avoid altering the phenomenon, no guest screenshot/recording was used. Observations were made by the user in the VM.

## 2. Reproduction summary

| Condition | Result |
|---|---|
| DockAltTab quit; AppleScript alert | Visible at delayed inspection |
| DockAltTab running; Screen Recording skipped/off | AppleScript alert, Finder Connect to Server, Script Editor dialog: all visible for 10 s |
| Screen Recording granted; background capture disabled; switcher hidden | Finder, Script Editor, and exact alert: visible; app log confirmed permission granted; no capture-path entries |
| Screen Recording granted; background capture enabled; switcher hidden | **Reproduced:** identical AppleScript alert appeared then blanked almost immediately; system logs show actual SCK screenshots |
| One minimal SCK capture, DockAltTab absent | **Reproduced:** blank, including on a fresh alert after no-capture and enumeration-only controls |
| Capture a normal app window (Script Editor) | **Not blank** |
| Capture Finder Connect to Server window | **Not blank** |
| Capture Finder Empty Trash confirmation | **Blank** |

**Minimum conditions confirmed:** Screen Recording permission must be granted, and an actual capture request must be made against the affected alert/confirmation window. Permission/preflight alone is insufficient; `SCShareableContent` enumeration alone is insufficient. The switcher need not be visible, and background capture is enough. A single capture is sufficient; overlapping requests, retained thumbnails, the first-use acknowledgement prompt, DockAltTab event taps/AX observers, and preview UI are all unnecessary.

## 3. Exact minimal reproduction

A purpose-built probe (`DockAltTab44Probe.app`, separate bundle ID, ad-hoc signed, no DockAltTab code, no event tap, no AX observer, no preview windows) was installed only after the release reproduction. It performs no capture at launch.

Against a fresh system alert, with DockAltTab quit:

1. No capture, 20 s: visible.
2. `SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false)` only, 20 s: visible.
3. One request:
   ```swift
   SCScreenshotManager.captureSampleBuffer(
       contentFilter: SCContentFilter(desktopIndependentWindow: window),
       configuration: config // BGRA, cursor off, 520×404, no retention
   )
   ```
   Callback returned a valid buffer with no error in ~30 ms. User: **blanked almost immediately**.
4. `ignoreGlobalClipSingleWindow=false` and `ignoreShadowsSingleWindow=false` on another fresh alert: **still blanked**. On an alert previously blanked and recovered via Mission Control, `false/false` could appear protected for 20 s, while defaults blanked within 15 s. That is a post-recovery state effect, not a reliable fix. A fresh dialog remains vulnerable regardless of these flags.

A successful callback therefore only proves the frame was captured; it does **not** prove the source window remained renderable.

## 4. What exactly goes blank

The affected surfaces are the special modal alert/confirmation windows, not ordinary windows or all sheets:

- AppleScript `display alert` content window: 260×202, CG layer 8, with a 410×352 companion (75-point margin) owned by the same process.
- Finder Empty Trash confirmation: 260×234, CG layer 8, with a 410×384 companion.
- Finder Connect to Server: 486×234, CG layer 0, ordinary titled window — unaffected.
- Script Editor normal document window — unaffected.

The alert content window has no `kCGWindowIsOnscreen` marker while the companion does; however this pattern also occurs when the user sees the alert correctly, so it is **not** diagnostic of blanking. DockAltTab's own panels were not onscreen over the alert, ruling out a preview overlay. The blank content is the actual source window.

Quitting DockAltTab did **not** repair an already-blank alert. Mission Control (entered via the menu-bar Spotlight icon) made the contents visible; they remained visible after Escape. The reporter's Print Screen recovery was not independently tested here.

## 5. DockAltTab source findings (HEAD = v4.00.2)

- `src/logic/ScreenRecordingPermission.swift`: preflight checks only; only the explicit settings button requests access. Polling every 5 s is not recording.
- `src/logic/Windows.swift:115–134`: background capture is eligible even when the switcher is hidden. `captureWindowsInBackground=false` plus never opening the switcher prevents capture; hidden switcher alone does not.
- `src/logic/events/WindowCaptureEvents.swift:5–78`: on macOS 27 this uses `SCShareableContent` + `SCScreenshotManager.captureSampleBuffer` with `SCContentFilter(desktopIndependentWindow:)`. The SCStream/video path is commented out. The private `CGSHWCaptureWindowList` path is used for macOS 15 / pre-14, not here.
- `src/logic/events/AccessibilityEvents.swift`: window creation/focus events call `refreshOpenUiAfterExternalEvent`, which schedules capture before checking whether the switcher is visible. A newly appearing dialog can therefore be captured with the switcher hidden.
- `WindowDiscriminator` accepts `AXDialog` windows. `refreshThumbnailsAsync` does not consult `shouldShowTheUser` or Exceptions, so **Exceptions/Hide do not exclude a window from capture**.
- No source code sets `ignoreShadowsSingleWindow` or `ignoreGlobalClipSingleWindow`; on this OS/SDK both default to true. Flags are not a reliable mitigation for fresh alerts.

## 6. Crash report: symbolicated separately

The crash is **unrelated to the blanking** and not on a capture stack. The matching archive dSYM is:

`~/Library/Developer/Xcode/Archives/2026-11-19/DockAltTab 4.00.2 14.49.02.xcarchive/dSYMs/DockAltTab.app.dSYM`

arm64 UUID `1785825D-8233-3BF6-ABFA-734A938FDA32` matches the reporter's crash and GitHub release. With image base `0x10012c000`, the chain resolves to:

| Offset | Symbol |
|---:|---|
| 390832 | `NSScreen.repositionPanel(_:)`, `Screens.swift:115` |
| 668672 | `TilesPanel.repositionOrFreeze()` |
| 1083076 | `App.refreshUi(_:)`, `App.swift:288` |
| 701488 | `TilesView.enableSearchEditing()`, `TilesView.swift:110` |
| 870740 | `ControlsTab.executeAction(_:)` |
| 158292 | `triggerMatchingShortcuts(...)` |
| 153596 | keyboard local-monitor closure, `KeyboardEvents.swift:92` |
| 1076092 | NSEvent closure thunk |
| 8832 / 9040 | `-[AppCenterApplication sendEvent:]` / `main` |

Disassembly confirms failure immediately after the first `swift_dynamicCast` in the DockAltTab-mode branch:

```swift
let scrollView = TilesPanel.shared.contentView?.accessibilityChildren()?.first as! NSView
```

The code assumes the first accessibility child is the thumbnails container. `TilesView.updateBackgroundView()` adds the search field first, and enabling search changes the exposed hierarchy. The runtime source-object type is not in the crash report. The next forced cast on line 116 is also unsafe. Not reproduced independently; no evidence links it to blank dialogs. Separate fix: retain typed layout references instead of relying on accessibility-child order, and handle empty tiles.

## 7. Third-party applications

None of the reporter's utilities were installed or launched. They are **not required** for reproduction: the clean VM reproduced the failure with DockAltTab alone and with a minimal probe. This does not prove they can never contribute on another machine, but the blanking cause here is independent of them. Per-app testing was therefore stopped once the OS-level trigger was isolated.

## 8. Recommended fix and next experiment

**Best app-side mitigation:** do not issue ScreenCaptureKit window screenshots for the affected modal alert/confirmation surfaces. Identify them by their AX dialog role/subrole (and, if necessary, CG layer 8 + companion-window shape), store that state on `Window`, and exclude them in `refreshThumbnailsAsync`/`WindowCaptureScreenshots`. Exceptions must be enforced in capture eligibility, not only UI visibility. This preserves ordinary-window thumbnails and avoids the OS bug.

**Alternative to test:** route those windows through the existing private `CGSHWCaptureWindowList` path (or a full-display capture + crop) and verify on a fresh alert that contents remain visible. This was not tested; do not ship it as proven.

**Do not rely on** setting `ignoreShadowsSingleWindow`/`ignoreGlobalClipSingleWindow` false: a fresh alert still blanked.

**User workaround until fixed:** keep `captureWindowsInBackground` off and avoid invoking the switcher/Dock previews while a confirmation is open. Quitting does not repair an existing blank; Mission Control restores it (reporter also reports Print Screen).

**Apple:** this is reproducible with a minimal ScreenCaptureKit program and no third-party code. File Feedback with the probe, OS build, target window shape, and logs.

## 9. Evidence and state

- Local evidence: `~/Library/Logs/DockAltTab-issue44-2026-11-24/` — baseline/process inventory, issue text/comments, symbolication/disassembly, probe source/build notes, and raw test logs including `first-blank-system.log`, `probe-single-*`, `fresh3-*`, `finder-empty-trash-default-capture.txt`, `normal-window-default-capture.txt`.
- Guest evidence (before cleanup): `~/Desktop/DockAltTab-44-evidence/` — preference exports, DockAltTab debug logs, capture-comparison timeline, probe log and test alerts.
- Changes during investigation: Accessibility granted and Screen Recording granted to DockAltTab (user-authorized). `captureWindowsInBackground` was temporarily set false then true, and finally deleted again to restore the original absent key. DockAltTab was quit for isolation. A separate probe app was installed and granted Screen Recording; it was quit and removed, and its specific TCC grant was reset (`tccutil reset ScreenCapture com.steventheworker.DockAltTabIssue44Probe`). No suspected third-party utility was installed; no TCC-wide reset, SIP change, protected-file edit, or investigator-requested reboot. The two Finder dialogs opened for the last test may still be open; close them normally.
- The report intentionally distinguishes confirmed results from hypotheses. The exact WindowServer/AppKit mechanism inside macOS 27.2.1 is not proven; the externally observable causal chain is.
