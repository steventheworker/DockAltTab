# Issue 44 — ScreenCaptureKit alert-blanking fix

Branches:
- `fix/issue-44-sck-alert-blanking` — initial layer-8 fix
- `fix/issue-44-alert-blanking-followup` — Log Out layer, fresh-state recheck

## What changed

DockAltTab refuses to submit capture requests for top-level system
alert/confirmation windows. The exclusion is not version-gated.

Classification (public APIs only, no bundle-ID list, no new private APIs):

- AX role `AXWindow`
- AX subrole `AXDialog`
- no WindowServer parent (fresh parent id `0`, so sheets are not matched)
- WindowServer layer is one of:
  - `kCGModalPanelWindowLevel` (8): AppleScript alerts, Finder confirmations
  - `kCGScreenSaverWindowLevel` (1000): the loginwindow Log Out confirmation

On macOS 27, the affected surfaces are pairs of windows: the AX dialog content
window and a larger, concentric companion window behind it. At rest the
companion is exactly 75 points larger on every side; during the scale-in
animation both windows scale together. The companion is logged as a
confirmation, but it is deliberately not required:

- Finder creates the content window a few milliseconds before the companion.
  Requiring it allowed one capture in that gap, which blanked the Finder Empty
  Trash dialog.
- macOS 26 alerts have no companion at all.

The Log Out confirmation (`loginwindow`, 267x266 at layer 1000) has the same
AX shape and a 417x416 companion; it was still blanked by the first fix because
only layer 8 was checked.

## Fresh-state enforcement

The first fix could fail when a Finder confirmation was dismissed and quickly
re-opened. The cause was stale state: `SCWindow` objects are cached, and a
re-opened dialog can reuse a wid; the cached layer/parent could be stale.

The final fix uses fresh WindowServer data at the capture decision point:

1. `Windows.refreshThumbnailsAsync` filters candidates before submitting work.
2. `WindowCaptureScreenshots.oneTimeCapture` re-checks immediately before the
   ScreenCaptureKit request using a fresh `CGWindowList` snapshot:
   - fresh layer
   - fresh WindowServer parent (batched `SLSWindowQueryWindows`)
   - current AX role/subrole
   - if the candidate is missing from the snapshot, skip this attempt
     (fail closed) rather than risk a freshly-created alert.
3. `Windows.removeWindows` invalidates the cached `SCWindow` for removed wids,
   so a quickly re-opened dialog gets a fresh enumeration.

The window stays in `Windows.list`; only thumbnail capture is skipped. Switcher
order, keyboard navigation, search, focus and Exceptions behavior are unchanged.

## Why the rule is narrow

- Ordinary windows use layer 0.
- Sheets are `AXSheet` and/or have a WindowServer parent, so they are not
  `AXWindow` + parentless.
- Minimized/hidden windows are not at layers 8 or 1000.
- No Apple process bundle IDs are checked.
- Only modal/system alert AX dialogs lose a thumbnail. They remain selectable
  with their app icon.

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

Test build: separate `~/Applications` copy with a distinct bundle ID, background
capture enabled.

| Target | Result |
|---|---|
| AppleScript `display alert` (fresh + repeated) | Excluded on every refresh; remained visible |
| Finder Empty Trash confirmation | Capture queued before the companion appeared; capture-time guard blocked it; remained visible |
| Finder Empty Trash, 5 rapid open/click/Escape cycles | Every dialog blocked at capture time; visible all 5 times |
| Log Out confirmation (Apple menu / Shift-Cmd-Q) | `loginwindow` layer 1000; capture-time guard blocked it; remained visible |
| Script Editor ordinary window | Captured normally (not excluded); remained visible |
| TextEdit Save sheet | `AXSheet`, rejected by `WindowDiscriminator` as before; remained visible |

Log evidence:

```
not capturing system alert window: ... (wid:768 title:loginwindow) layer:1000 parent:0 companion:769
capture-time alert check: ... (wid:768 title:loginwindow) layer:1000 parent:0 role:AXWindow sub:AXDialog excluded:true
capture-time alert check: ... (wid:773 title:Finder) layer:8 parent:0 role:AXWindow sub:AXDialog excluded:true
```

The 5-cycle test produced five new dialog wids; every one was blocked with
`excluded:true` at capture time.

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

## Version gating

No macOS version check is used.

The classifier relies on AX `AXWindow`/`AXDialog`, no WindowServer parent, and a
system alert layer. Those properties are not macOS 27-only. On the macOS 26.7.3
host (`house`), a fresh AppleScript alert was inspected and had the same
`AXWindow`/`AXDialog` shape at layer 8 (260x202), but it was a single onscreen
window with **no companion**. On macOS 27 the same alert has a separate content
window plus a larger onscreen companion. The rule matches both; the companion is
only a macOS 27 confirmation used for logging. Layer 1000 covers the loginwindow
Log Out confirmation on macOS 27.

The early filter runs before either capture backend, so it applies to the
private `CGSHWCaptureWindowList` path on macOS 15 and earlier as well as the
ScreenCaptureKit path. The capture-time guard lives in the macOS 14+
ScreenCaptureKit path. Skipping modal alert/dialog thumbnails on earlier
versions is harmless and arguably desirable: they are transient, their preview
has little value, and they can contain confirmation or permission text.

A version gate would add an OS-specific branch without preventing any known
bug, while leaving older versions capturing the same modal alert surfaces. It
would also make the macOS 26/27 behavior diverge unnecessarily.

## Tests

Classifier unit tests (standalone, no TCC or GUI needed):

```sh
./docs/issues/44/run-classifier-tests.sh
```

Build check (separate DerivedData so the user's normal build is not replaced):

```sh
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug -configuration Debug \
  -derivedDataPath /tmp/DockAltTab-issue44-build
```

Existing unit tests:

```sh
xcodebuild test -workspace alt-tab-macos.xcworkspace -scheme Test -configuration Debug \
  -derivedDataPath /tmp/DockAltTab-issue44-tests -only-testing:unit-tests
```

Results: 21 classifier cases pass; app build succeeds; existing unit test suite
passes.

## Manual regression steps

1. Build and launch a test copy of DockAltTab with Screen Recording enabled and
   background capture on. Do not use the normal install.
2. Open `osascript -e 'display alert "System Alert" message "test" as critical buttons {"Cancel", "OK"} default button "OK"'`.
3. Watch the alert for several seconds **without taking a screenshot**. It must
   keep its title, message and buttons.
4. Open the Finder Empty Trash confirmation (`Cmd+Shift+Delete` with items in the
   Trash) and watch it. It must stay visible. Cancel it; do not confirm.
5. Repeat open/click-body/Escape several times quickly. Each dialog must stay
   visible.
6. Open the Apple menu → Log Out (or Shift-Cmd-Q). The Log Out confirmation must
   stay visible. Cancel it; do not log out.
7. Use an ordinary window (e.g. Script Editor) and a save sheet. They must be
   captured normally and stay visible.
8. Quit the test build and remove it.

## Limitations

- The classifier is version-sensitive: it relies on the AX modal-dialog and
  layer-8/1000 shape seen on macOS 26 and 27. If a future macOS changes it, the
  classifier fails open (capture resumes), which is safer than excluding
  ordinary windows.
- The capture-time guard is on the ScreenCaptureKit backend used by macOS 27.
  The private `CGSHWCaptureWindowList` backend used on macOS 15 and earlier is
  not affected by this macOS 27 bug; the early filter still applies to it.
- Modal alert/confirmation windows at layers 8/1000 intentionally have no
  thumbnail. They still appear in the switcher with their app icon.
- If a candidate is missing from the fresh WindowServer snapshot, one capture
  attempt is skipped (fail closed). A later refresh will capture it if it is an
  ordinary window.
- This change does not address the separate forced-cast crash at
  `Screens.swift:115`.
