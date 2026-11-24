pi --session 01a20c2b-6169-756c-a3fc-309440863d6d

## Investigation complete

Full report: `issue-44-investigation.md`

### Root cause

Blank dialogs are a **macOS 27.2.1 ScreenCaptureKit bug triggered by capturing the special system alert/confirmation surface**:

- Screen Recording permission alone does not cause it.
- `SCShareableContent` enumeration alone does not cause it.
- **One** `SCScreenshotManager.captureSampleBuffer` request against the alert window is sufficient.
- It reproduces with DockAltTab fully quit using a minimal probe with no event taps, AX observers, or preview UI.
- The API returns a valid image successfully, then the source dialog blanks.
- Quitting DockAltTab does not repair an existing blank dialog; Mission Control restores it.

### Exact reproduction conditions

Tested on clean **macOS 27.2.1 (26B131)**:

1. Grant Screen Recording.
2. Create a system alert or confirmation dialog.
3. Capture its content window with `SCContentFilter(desktopIndependentWindow:)`.
4. Dialog contents blank almost immediately.

Overlapping captures, background capture UI, retained thumbnails, Exceptions, the switcher being visible, and the first-use Screen Recording acknowledgement prompt are **not required**.

### Scope

| Target | Result |
|---|---|
| AppleScript `display alert` | blanks |
| Finder Empty Trash confirmation | blanks |
| Finder Connect to Server window | stays visible |
| Script Editor normal window | stays visible |
| Enumeration without capture | stays visible |
| Permission/background capture disabled | stays visible |

The affected surfaces are the layer-8 modal alert/confirmation windows with a larger companion surface. Ordinary windows and some sheets are unaffected.

### Catch with capture flags

Setting `ignoreShadowsSingleWindow=false` and `ignoreGlobalClipSingleWindow=false` initially appeared protective on a restored alert, but a **fresh** alert still blanked. Mission Control recovery changes later behavior; it is not a fix.

### Crash report

Successfully symbolicated using the matching 4.00.2 dSYM. The failure is:

```swift
let scrollView = TilesPanel.shared.contentView?.accessibilityChildren()?.first as! NSView
```

at `Screens.swift:115`, reached through Dock-preview repositioning and search-enabled keyboard handling. This is a separate forced-cast bug, not the blank-dialog cause.

### Recommended fix

- **Primary:** exclude system alert/confirmation windows from ScreenCaptureKit capture. Identify them by AX role/subrole and, if needed, the layer-8/companion-window pattern; store that state on `Window` and enforce it in `refreshThumbnailsAsync`, not just UI visibility/Exceptions.
- **Alternative to test:** route those windows through the existing private `CGSHWCaptureWindowList` path or a display-capture-and-crop path. Not yet validated.
- **Do not** rely on the two capture flags as a fix.
- **Workaround:** disable background capture and avoid the switcher/Dock previews while a confirmation is open.
- File an Apple Feedback with the minimal probe; no third-party code is needed.

### Third-party apps

None of Lightshot, ScreenPal, Wispr Flow, Pesto, Explorer, or Wins were installed. They are not required for reproduction, so individual testing was stopped once the OS-level trigger was isolated.

### Cleanup

DockAltTab remains installed, quit, with Accessibility and Screen Recording granted. The diagnostic probe was quit, removed, and its specific TCC grant reset. The temporary capture preference was removed, restoring its original absent state. Evidence remains under:

`~/Library/Logs/DockAltTab-issue44-2026-11-24/`

The two Finder dialogs from the last test may still be open; they can be closed normally.
