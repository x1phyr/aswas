# MVP Manual Test Plan

Record macOS version, Finder version, display arrangement, app version, and signing type
with every run. Use a disposable test folder set where practical.

## 1. Build and launch

```sh
swift test
./Scripts/build-app.sh
open build/Release/aswas.app
```

Verify:

- `aswas` appears in the menu bar and has no required Dock presence.
- The main window opens from the menu item.
- The empty state and Save action are readable in light and dark appearance.
- Settings shows Finder Automation and Accessibility statuses.

## 2. Automation permission

1. Start with no Automation decision for this exact signed app identity.
2. Choose Save and verify the system requests Finder control only at that point.
3. Deny permission and verify a readable error with no retry loop.
4. Grant permission in System Settings, choose Check Again, and verify Granted.
5. Revoke permission while the app is running and verify the next operation fails cleanly.

Do not grant Accessibility for the baseline run. It should show Not Required.

## 3. Save and persistence

1. Open one Finder window for a folder with spaces and Unicode characters.
2. Save it as a named workspace.
3. Verify window/folder counts and the details path.
4. Quit and relaunch `aswas`; verify the workspace remains.
5. Rename the workspace and confirm its JSON filename remains the UUID.
6. Update from current Finder windows and verify a backup file is created.
7. Delete the workspace and verify its last JSON was backed up first.

## 4. Open restore

1. Save three Finder windows in icon, list, and column views.
2. Leave unrelated Finder windows open.
3. Restore in Open mode.
4. Verify unrelated windows remain and three new windows open.
5. Verify folders, view modes, positions, sizes, and the result summary.
6. Click Restore rapidly several times; verify only one operation starts at a time.

## 5. Replace restore

1. Open several ordinary Finder windows plus a non-Finder file dialog if available.
2. Request Replace and inspect the explicit path preview.
3. Cancel and verify nothing closes.
4. Request again and confirm.
5. Verify only previewed readable Finder windows close; the file dialog and other apps remain.
6. Verify the target workspace then restores and reports partial failures independently.

## 6. Save & Close

1. Open multiple readable Finder windows.
2. Choose Save & Close, then cancel; verify nothing changes.
3. Complete Save & Close and verify data exists before the windows close.
4. Run `SaveAndCloseServiceTests.neverClosesWindowsWhenPersistenceFails` as the automated
   forced-failure proof; do not alter real Application Support permissions for this test.
5. Restart the app and restore the saved workspace.

## 7. Missing and unusual paths

- Delete or move one saved folder, then restore: the missing path is skipped and others open.
- Disconnect an external disk and a network share, then restore.
- Test iCloud Drive, symlink, spaces, Chinese text, and decomposed Unicode names.
- Verify no automatic path guessing occurs.

## 8. Displays and coordinates

Test each arrangement:

- Single display
- Secondary display left, right, and above the main display
- Negative X and negative Y window coordinates
- Different scale factors
- Resolution change
- Saved display removed

Verify windows remain fully visible, have reasonable minimum size, and use normalized
placement on the fallback main display.

## 9. Finder lifecycle and damage recovery

- Restart Finder between capture and restore.
- Restart Finder during restore and verify structured partial results.
- Place an invalid `broken.json` in `workspaces/`, relaunch, and verify other data loads
  while the invalid file moves to `corrupt/`.
- Verify logs contain operation counts but do not expose full private paths by default.

## 10. Launch at Login and release artifact

- Move a Developer ID signed build to Applications before testing Launch at Login.
- Enable and disable Launch at Login and verify `SMAppService` status after logout/login.
- Run `codesign`, `spctl`, notarization, and stapling checks from `Docs/Release.md`.
- Repeat first-run TCC testing with the exact notarized artifact.

## 11. Permission-gated Finder tabs

1. Without Accessibility permission, save a multi-tab Finder window and verify the save is rejected with a clear explanation; no workspace is overwritten and no Finder window closes.
2. Grant Accessibility from Settings and create two Finder windows with multiple tabs, Unicode paths, and different selected tabs.
3. Save and inspect the workspace detail: verify every folder, window grouping, tab order, and selected tab.
4. Restore in Open mode and verify the same grouping, order, and selected tabs while unrelated windows remain open.
5. Revoke Accessibility and verify an existing multi-tab workspace is not restored partially; the app requests permission and leaves current Finder windows unchanged.
6. Repeat on each supported macOS release and in English and Simplified Chinese; AX role matching must not depend on localized labels.
7. Open two independent Finder windows with exactly the same position and size. Verify they remain two windows after save and restore rather than becoming one tab group. This is a release blocker until it passes reliably.
8. In one window, open two different folders that have the same final folder name. Verify capture either proves the order correctly or rejects the save; it must never silently accept an invented order.
9. Save two multi-tab windows with overlapping frames. Restore them and verify every additional tab is attached to the intended window.
10. During a disposable test, introduce enough Finder focus delay that Command-T does not create a tab. Verify aswas detects the missing tab instead of changing the existing selected tab and reporting success.

## 12. Menu-bar presentation

1. Close the aswas main window while leaving the menu-bar app running.
2. Run an Open restore from the menu and verify the result or error is visible.
3. Set Replace as the default mode, request restore from the menu, and verify a confirmation UI appears before any Finder window closes.
4. Deny a permission request initiated from Settings and verify the explanation appears in the currently visible surface.

The current implementation hosts shared notices and Replace confirmation in the main window,
so the closed-main-window cases above are known review findings and release blockers.

## 13. Schema compatibility

1. Place a valid workspace JSON with a schema version newer than the running app in `workspaces/`.
2. Verify the app does not describe it as damaged or silently discard it.
3. Verify the original bytes remain recoverable and the user receives a version-compatibility explanation.

The current repository isolates every decode failure into `corrupt/`, including a newer
unsupported schema. Treat downgrade compatibility as a known issue until errors are classified.
