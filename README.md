# DockAltTab

**Window previews for the macOS Dock**, built directly on top of [AltTab](https://alt-tab-macos.netlify.app/).

Hover a Dock icon and its windows pop up right above it; the AltTab switcher (`⌥⇥` by default) is still there too.

This used to be two apps: a *DockAltTab* companion that drove a "scriptable" fork of AltTab through AppleScript. This repository merges them — the DockAltTab behaviour now lives inside the AltTab codebase (see [`src/DockAltTab`](src/DockAltTab)), so there is **no companion app and no AppleScript round-trip**. Everything AltTab does (the switcher, the settings window, Sparkle updates, …) is still included.

Website: <https://dockalttab.netlify.app>

## What it does

- **Dock hover previews** — hover any Dock app icon to see its windows, positioned and clipped relative to the icon (magnification- and edge-aware).
- **Thumbnail previews** — hover a window thumbnail to get a large preview of that window; the delay is configurable.
- **No unwanted Space switching** — clicking a Dock icon in the click-driven modes is handled by DockAltTab, so activating an app whose windows live on another Space unhides it first and only activates once it is visible, instead of triggering a Space swoosh.
- **The full AltTab switcher** and settings remain available.

## Modes

DockAltTab has three interaction styles, selectable in its preferences:

| Mode | Hover a Dock icon | Left-click a Dock icon | Middle-click a Dock icon |
| --- | --- | --- | --- |
| **MacOS** | show previews | native Dock behaviour | native Dock behaviour |
| **Windows** | show previews | non-frontmost app → activate it; frontmost app → hide it | — |
| **Ubuntu** | — | non-frontmost app → activate it; frontmost app with ≥2 windows → toggle previews; otherwise → hide it | show previews (if the app has ≥1 window) |

In every mode, a click that DockAltTab acts on is swallowed, so the native Dock cannot also fire a Space switch.

## Preferences

The menu-bar menu has a **DockAltTab** item (first in the list) that opens the *DockAltTab Preferences* window. It contains the Preview Settings:

- **Mode** — MacOS / Windows / Ubuntu
- **Show Delay** — delay before previews appear when hovering an icon
- **Hide Delay** — delay before previews disappear when leaving
- **Thumbnail Preview Delay** — delay before a hovered thumbnail expands
- **Enable Thumbnail Previews**
- **Reposition preview after dock magnification** — follow the icon while the Dock magnification animation settles
- **Preview Distance** — gap between the previews and the Dock
- **Keep dock showing during previews** — keep an auto-hiding Dock visible while previewing

The DockAltTab menu-bar icon (a DockAltTab logo) is the default; the other AltTab icons remain selectable under **Settings → General → Menubar icon**.

## Permissions

- **Accessibility** — required (global event taps + Accessibility queries of the Dock and windows).
- **Screen Recording** — required for window thumbnails.

On first launch the app requests them; grant them in System Settings and relaunch.

## Install / build

Build from source with Xcode (the workspace includes the CocoaPods dependencies):

```sh
# from the repository root
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug -configuration Debug build
```

Or open `alt-tab-macos.xcworkspace` in Xcode and run the **Debug** scheme. The product is `DockAltTab.app`.

CocoaPods are vendored under `Pods/`, so a separate `pod install` is normally not required.

## Scripting

The app is scriptable (this comes from the scriptable AltTab fork). The dictionary is in [`DockAltTab.sdef`](DockAltTab.sdef).

#### Basic commands

- **hide** — hide the overlay/UI.
- **show** — show all app windows (the regular AltTab shortcut).
- **showApp** — show a specific app's windows (ignores the blacklist).
  - `appBID` — bundle identifier of the app.
  - `x` / `y` *(optional)* — position of the Dock icon; resets on hide.
  - `dockPos` *(optional)* — `bottom` / `left` / `right`, helps position/clip the previews.
- **trigger** — go to the next window without showing the overlay.

<details>
<summary>Miscellaneous commands</summary>

- **countWindows** (`appBID`) — number of windows for an app, across all Spaces.
- **countWindowsCurrentSpace** (`appBID`) — number of windows for an app in the current Space.
- **countMinimizedWindowsCurrentSpace** (`appBID`) — number of minimized windows for an app in the current Space.
- **countWindowStats** (`appBID`) / **countAllWindowStats** — window-count records.
- **deminimizeFirstMinimizedWindowFromCurrentSpace** (`appBID`) — deminimize the app's first window minimized on the current Space.
- **keyState** (`key`) — whether a key is currently pressed.
- **appSetting** (`named`) — read a setting used for `showApp` previews (`appsToShow`, `showHiddenWindows`, `showFullscreenWindows`, `showMinimizedWindows`, `spacesToShow`, `screensToShow`, `showTabsAsWindows`).
- **thumbnailPreview** — show the large preview of the selected window.
- **repositionThumbnails** (`{x, y}`) — reposition the preview panel.

</details>

Example:

```applescript
tell application "DockAltTab" to showApp appBID "com.apple.Safari"
tell application "DockAltTab" to showApp appBID "com.apple.Safari" x 0 y 0 dockPos "bottom"
tell application "DockAltTab" to hide
```

> Internally, DockAltTab no longer needs these commands — it calls the same code directly — but they are kept for automation.

## Notes / differences

- On launch, if the Dock's `showhidden` preference is off, DockAltTab enables it and restarts the Dock once (translucent icons for hidden apps).
- Some apps' windows are ignored by personal preference, e.g. BetterTouchTool "pinned"/floating windows and Screenhint floating windows.
- Preview button order: Exit first, Quit last.
- Fading is faster for DockAltTab previews (111 ms) than for regular previews (333 ms).
- Window controls auto-reopen after closing a window, so repeated clicks keep working.

## Credits

DockAltTab is built on [AltTab](https://github.com/lwouis/alt-tab-macos) by Louis Pontoise and contributors, and on the ["scriptable" fork](https://github.com/steventheworker/alt-tab-macos/tree/scriptable) by steventheworker. Both are licensed under **GPL-3.0**; see [`LICENCE.md`](LICENCE.md).

Sister app: [Dock Exposé](https://dockexpose.netlify.app).
