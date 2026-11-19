# Screen Recording regression checks (#44)

Run these manually with a single DockAltTab copy, launched normally without a debugger. Repeat with the exported/distributed release. The project overrides both local Debug and Release targets to use `Apple Development` (despite the identities in the xcconfig files); `scripts/make-release.sh` exports with `Developer ID`. Do not assume the development and distributed apps have equivalent TCC histories.

## Preparation

Prefer a clean macOS user account. Otherwise quit DockAltTab and, only when ready to discard **this app's** Screen Recording decision, run:

```sh
tccutil reset ScreenCapture com.steventheworker.DockAltTab
```

Keep Accessibility authorized. For the first-run case, uncheck “Use the app without this permission” before quitting, or remove only that preference:

```sh
defaults delete com.steventheworker.DockAltTab screenRecordingPermissionSkipped
```

Do not reset all apps' Screen Recording permissions. Record the macOS version, app version, installed path and signing identity for each run.

## Cases

1. **Fresh authorization state:** Launch and leave DockAltTab's permissions window open for at least 10 seconds. No macOS Screen Recording prompt should appear. Opening “Check permissions…” must also be silent.
2. **Skip:** Check “Use the app without this permission”. With Accessibility authorized, launch must finish. Dock previews and keyboard window switching must work using app icons/titles, without thumbnails or a large window preview. Exercise background window creation, movement and closing, then quit/relaunch; no Screen Recording prompt should appear.
3. **Explicit request:** The menu's “Grant permission” button should open DockAltTab's permissions window, not restart or request access. Only clicking “Open Screen Recording Settings…” may request access and open System Settings. On a fresh TCC record, the system prompt is expected here.
4. **Deny:** Deny the request, wait at least 10 seconds and reopen the permissions window. No automatic retry prompt. Check Skip and confirm the app remains usable. A previously denied app may require enabling access directly in System Settings on the next button click.
5. **Grant:** Enable permission in System Settings. If status remains stale, quit and reopen DockAltTab (some macOS versions cache preflight results for the process lifetime). Thumbnails and large previews should return. An existing grant should remain recognized even if Skip was previously checked.
6. **Revoke:** Revoke permission while captures are pending. When preflight reports denial, pending captures must stop, existing thumbnails/large previews must clear, and icons/titles must remain usable. Follow any macOS-required restart; verify the next launch remains silent with Skip selected.
7. **Both capture backends:** Repeat on macOS 15 (private screenshot API) and macOS 14 or 26+ (ScreenCaptureKit), if available.

## Separate system-dialog report

This fixes the permission probe that could itself generate dialogs, not a verified cause of the reported blank square. Repeat a specific permission prompt, confirmation sheet and system alert with DockAltTab quit, running without Screen Recording, and running with it. Capture the exact action, owning process/window ID and whether the issue is visual corruption, stolen focus, or blocked input. Exceptions filter window visibility/shortcuts; they do not control permission requests. Dock-hover mode currently bypasses Hide exceptions.

The automated `ScreenRecordingPermissionTests` use fake CoreGraphics permission calls; they cover the permission policy without displaying prompts or modifying TCC. They do not replace these OS/UI checks.
