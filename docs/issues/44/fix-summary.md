# Issue 44 — ScreenCaptureKit alert-blanking fix

Branch: `fix/issue-44-sck-alert-blanking`

## What changed

DockAltTab now refuses to submit ScreenCaptureKit window captures for macOS 27
system alert/confirmation surfaces.

Classification (public APIs only, no bundle-ID list, no new private APIs):

- AX role `AXWindow`
- AX subrole `AXDialog`
- no WindowServer parent (`parentWid == 0`, so sheets are not matched)
- `kCGWindowLayer == kCGModalPanelWindowLevel` (8)

The affected surfaces are pairs of windows: the AX dialog content window and a
larger, concentric companion window behind it. At rest the companion is exactly
75 points larger on every side; during the scale-in animation both windows scale
together. The companion is logged as a confirmation, but it is deliberately not
required: Finder creates the content window a few milliseconds before the
companion. Requiring the companion allowed one capture in that gap and blanked
the Finder Empty Trash dialog during testing.

The exclusion is enforced twice:

1. `Windows.refreshThumbnailsAsync` filters candidates before submitting capture
   work (the normal path).
2. `WindowCaptureScreenshots.oneTimeCapture` re-checks the actual `SCWindow`
   layer immediately before the ScreenCaptureKit request. This closes the race
   where a capture was queued before `CGWindowList` reported the new window.

The window stays in `Windows.list`; only thumbnail capture is skipped. Switcher
order, keyboard navigation, search, focus and Exceptions behavior are unchanged.

## Why the rule is narrow

- Ordinary windows use layer 0.
- Sheets are `AXSheet` and/or have a WindowServer parent, so they are not
  `AXWindow` + parentless.
- Minimized/hidden windows are not at the modal-panel layer.
- No Apple process bundle IDs are checked.
- Only modal-panel AX dialogs lose a thumbnail. They remain selectable with
  their app icon.

## Reproduction and validation (main Mac, macOS 27.2.1 / 26B131)

Local reproduction with a minimal probe that had its own Screen Recording grant:

- Probe idle, fresh `display alert`: visible after 8 s.
- One `SCScreenshotManager.captureSampleBuffer` against the alert content window
  (`SCContentFilter(desktopIndependentWindow:)`, BGRA, cursor off): the user saw
  the alert contents disappear immediately.
- A display screenshot or Mission Control restored the alert, so screenshots
  taken after a capture must not be used as the visibility check.

Important: this is why the first physical-Mac checks looked negative. Display
capture itself restores the blanked surface; only direct visual observation
showed the blank state.

## Regression results with the fixed test build

Test build: separate `~/Applications/DockAltTabIssue44Test.app`, separate
bundle ID, background capture enabled.

| Target | Result |
|---|---|
| AppleScript `display alert` (fresh + repeated) | Logged as excluded on every refresh; remained visible |
| Finder Empty Trash confirmation | First capture was queued before the companion appeared; the capture-time guard blocked it; remained visible |
| Finder Connect to Server | Captured normally (not excluded); remained visible |
| Script Editor ordinary window | Captured normally (not excluded); remained visible |
| TextEdit Save sheet | `AXSheet`, rejected by `WindowDiscriminator` as before; remained visible |
| Repeated alert open/close | Each new alert was classified from fresh window data; no stale state |

Log evidence from the fixed build:

```
WindowCaptureExclusion.swift ... not capturing system alert window: ... (wid:29586) companion:none
WindowCaptureEvents.swift ... not capturing system alert window at capture time: ... (wid:29586) layer:8
```

The first line shows the early filter, the second shows the capture-time guard
blocking a request that had already been queued.

## VM secondary validation (macOS 27.2.1 / 26B131)

The VM reproduced the bug with its existing unfixed DockAltTab 4.00.2:

- The unfixed app logged `oneTimeScreenshots ... cached:[1304]` for an AppleScript
  alert content window. The user saw the dialog blank, and moving the window
  produced repeated captures.
- The fixed test build was signed with Developer ID and the same bundle ID as
  the VM's normal install, so it reused the existing Accessibility and Screen
  Recording grants without new TCC entries. It was installed at
  `~/Applications/DockAltTabIssue44Test.app`; the normal `/Applications`
  install was not touched.
- The fixed VM build logged:
  `not capturing system alert window: ... (wid:1288 title:Finder) companion:1289`
  and
  `not capturing system alert window: ... (wid:1330 title:osascript) companion:1331`.
  The user confirmed the AppleScript alert remained visible.
- The VM test app was removed afterwards. The normal VM install and its
  permissions were left in place. Logs were copied to
  `~/Library/Logs/DockAltTab-issue44-2026-11-24/vm-secondary/`.

## Tests

Classifier unit tests (standalone, no TCC or GUI needed):

```sh
./docs/issues/44/run-classifier-tests.sh
```

Build check (uses a separate DerivedData path so the user's normal build is not
replaced):

```sh
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug -configuration Debug \
  -derivedDataPath /tmp/DockAltTab-issue44-build
```

Existing unit tests:

```sh
xcodebuild test -workspace alt-tab-macos.xcworkspace -scheme Test -configuration Debug \
  -derivedDataPath /tmp/DockAltTab-issue44-tests -only-testing:unit-tests
```

Results: classifier tests pass; app build succeeds; existing unit test suite
passes.

## Manual regression steps

1. Build and launch a test copy of DockAltTab with Screen Recording enabled and
   background capture on. Do not use the normal install.
2. Open `osascript -e 'display alert "System Alert" message "test" as critical buttons {"Cancel", "OK"} default button "OK"'`.
3. Watch the alert for several seconds **without taking a screenshot**. It must
   keep its title, message and buttons.
4. Open the Finder Empty Trash confirmation (`Cmd+Shift+Delete` with items in the
   Trash) and watch it. It must stay visible. Cancel it; do not confirm.
5. Open Finder → Connect to Server (`Cmd+K`). It must be captured normally and
   stay visible.
6. Use an ordinary window (e.g. Script Editor) and a save sheet. They must be
   captured normally and stay visible.
7. Close and reopen alerts several times; each must remain visible.
8. Quit the test build and remove it.

## Version gating

No macOS version check is used.

The classifier relies on AX `AXWindow`/`AXDialog`, no WindowServer parent, and
CG layer 8. Those properties are not macOS 27-only. On the macOS 26.7.3 host
(`house`), a fresh AppleScript alert was inspected and had the same
`AXWindow`/`AXDialog` shape at layer 8 (260x202), but it was a single onscreen
window with **no companion**. On macOS 27 the same alert has a separate
content window plus a larger onscreen companion. The rule matches both; the
companion is only a macOS 27 confirmation used for logging.

The early filter runs before either capture backend, so it applies to the
private `CGSHWCaptureWindowList` path on macOS 15 and earlier as well as the
ScreenCaptureKit path. The capture-time guard lives in the macOS 14+
ScreenCaptureKit path. Skipping modal alert/dialog thumbnails on earlier
versions is harmless and arguably desirable: they are transient, their preview
has little value, and they can contain confirmation or permission text.

A version gate would add an OS-specific branch without preventing any known
bug, while leaving older versions capturing the same modal alert surfaces. It
would also make the macOS 26/27 behavior diverge unnecessarily.

## Limitations

- The classifier is version-sensitive: it relies on the AX modal-dialog and
  layer-8 shape seen on macOS 26 and 27. If a future macOS changes it, the
  classifier fails open (capture resumes), which is safer than excluding
  ordinary windows.
- The capture-time guard is on the ScreenCaptureKit backend used by macOS 27.
  The private `CGSHWCaptureWindowList` backend used on macOS 15 and earlier is
  not affected by this macOS 27 bug; the early filter still applies to it.
- Modal alert/confirmation windows at layer 8 intentionally have no thumbnail.
  They still appear in the switcher with their app icon.
- This change does not address the separate forced-cast crash at
  `Screens.swift:115`.
