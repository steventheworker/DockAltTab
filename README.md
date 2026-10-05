## "scriptable" branch of [lwouis/alt-tab-macos](https://alt-tab-macos.netlify.app/)

**Download:** [AltTab-scriptable-1.94.3.zip](https://github.com/steventheworker/alt-tab-macos/releases/download/1.94.3/AltTab-scriptable-1.94.3.zip)

Made for use with [DockAltTab](https://dockalttab.netlify.app) (adds window previews to the MacOS dock)... it does so by sending AppleScript commands to AltTab.

# [AppleScript Dictionary / Docs](https://github.com/steventheworker/alt-tab-macos/blob/scriptable/AltTab.sdef)

#### <u>basic commands</u>

- **hide:** Hide Overlay/UI.
- **show:** Show all app windows. (Regular AltTab shortcut)
- **showApp:** Show specific app's windows. (ignores blacklist)
    - appBID: The bundle identifier of the app whose windows you want to show.
    - x: X-coordinate (optional)
    - y: Y-coordinate (optional)
    - dockPos: (optional) Helps AltTab know where previews will be positioned / clip, (especially for docks on the right (preview 'panel' width is relevant))
- **trigger:** Goes to the next window, without showing Overlay/UI.

<details>
  <summary><u>Miscellaneous / DockAltTab commands</u></summary>

#### <u>Miscellaneous / DockAltTab commands</u>

- **appSetting:** Read settings applied on showApp previews.
    - named: Name of the setting. (appsToShow, showHiddenWindows, showFullscreenWindows, showMinimizedWindows, spacesToShow, screensToShow, showTabsAsWindows)
- **countMinimizedWindowsCurrentSpace:** The number of (minimized) windows for an app (FROM the current space, especially useful for keeping minimized windows contained in the space they were originally minimized in).
    - appBID
- **countWindows:** The number of windows for an app (in all spaces).
    - appBID
- **countWindowsCurrentSpace:** The number of windows for an app (in the current space, especially useful for counting hidden windows (otherwise especially hard to do for the current space)).
    - appBID
- **deminimizeFirstMinimizedWindowFromCurrentSpace:** Deminimize app's first minimized window originally minimized on the current space.
    - appBID
- **keyState:** Whether a certain key is being pressed (see if AltTab overlay is absorbing modifier keys)
    - key: Name of the key you want to check the state of.
- **thumbnailPreview:** show focuspreview/targetpreview - ...
  </details>

### example usages:

`tell application "AltTab" to showApp appBID "com.apple.Safari"`

`tell application "AltTab" to showApp appBID "com.apple.Safari" x 0 y 0`

`tell application "AltTab" to hide`

# Other Differences

Some other changes I made out of personal preference / hesitation to submit a pull request:

- ignore some app's windows
    - [BetterTouchTool]() "pinned"/floating windows
    - [Screenhint]() floating windows
- Preview button order: Exit is 1st, Quit is last (opposed to vice-versa)
- faster fading (if fading enabled): 111ms for DockAltTab previews, 333ms for regular previews
- auto reopen controls after closing window (allows click spam to repeat close window quickly)

# Contributing

[How to build AltTab on Xcode](https://www.youtube.com/watch?v=iitm_r0BBck) --this youtube video shows how to build the official AltTab from lwouis (but this branch has been normalized to be able to build on m-series/apple silicon, so this may not be necessary)
