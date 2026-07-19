# Architecture

## Scope

`aswas` manages Finder workspaces only. It intentionally has no generic application
integration layer, plugin system, browser/session support, command runner, or AI feature.

## Layers

```text
SwiftUI / MenuBarExtra
        ↓
AppState (MainActor)
        ↓
Application Services
  WorkspaceLibraryService
  WorkspaceCaptureService
  WorkspaceRestoreService
  SaveAndCloseService
        ↓
Domain + Persistence
  WorkspaceSnapshot / validation / migration
  JSONWorkspaceRepository actor
        ↓
Finder Integration
  FinderAppleScriptIntegration actor
  AppleScriptRunner (main-thread NSAppleScript execution)
  Display and path infrastructure
        ↓
Finder AppleScript + AppKit display APIs
```

SwiftUI never contains AppleScript source or persistence logic. The Finder integration
returns domain results and structured warnings/errors. Finder operations and repository
writes are actor-isolated.

## Capture

1. Read ordinary Finder windows through the public Finder dictionary.
2. Capture window ID, active target folder, bounds, and current view.
3. Map Finder top-left coordinates to the current display descriptor.
4. Save both absolute and normalized frames.
5. Group AppleScript window-like entries into candidate physical windows using shared bounds.
6. When Accessibility is granted, match each candidate to an AX window and reconstruct tab order and selection from the tab strip.
7. Reject multi-tab capture with `tabsUnavailable` when order cannot be confirmed.
8. Validate, encode, fsync, back up the previous file, and atomically replace it.

The current grouping and ordering layer is heuristic: identical physical-window bounds and
duplicate Finder tab titles can be ambiguous. A future hardening pass should make AX physical
window identity primary and use bounds/title only as secondary matching signals.

Finder window IDs are returned only as runtime references. They are never persisted as
stable workspace identity because Finder can recycle them after restart.

## Restore

1. Load, migrate, and validate the workspace.
2. Check every path and skip unavailable folders.
3. Match the saved display by ID, name, geometry/scale, then current main display.
4. Map normalized frames when the display or resolution changed.
5. Clamp every frame to the visible display area.
6. In Replace mode, capture and precisely close current readable Finder window IDs.
7. Create each window, then restore bounds and view mode independently.
8. For multi-tab windows, focus the restored Finder window, request tabs serially, set each target, and restore the selected tab.
9. Return counts, skipped paths, warnings, and errors without failing unaffected windows.

The restore path currently selects an AX target primarily by expected frame and relies on a
timed Command-T sequence. Overlapping windows and focus delays therefore remain explicit
integration-test boundaries; posting a keyboard event must not be treated as proof that a new
tab exists.

`WorkspaceRestoreService` rejects a second restore while the first is running.

## Save & Close invariant

`SaveAndCloseService` cannot obtain managed window references until capture succeeds, and
does not call close until `WorkspaceCaptureService` has successfully returned from the
repository save. Tests assert that a forced persistence failure results in zero close calls.

## Persistence

- Format: readable JSON, ISO-8601 dates, schema version 1
- File identity: lowercased workspace UUID
- Atomicity: temporary file, file synchronization, atomic replacement
- Recovery: backup before overwrite/delete; damaged files moved to `corrupt/`
- Concurrency: repository actor serializes reads and writes

## Coordinates

Finder bounds use a global top-left coordinate space. AppKit displays use a global
bottom-left coordinate space. `SystemDisplayProvider` converts display frames around the
main display's top edge so saved window and display rectangles share Finder coordinates.
The pure `WindowPlacement` module is covered for single display, left/above displays,
negative coordinates, display removal, resolution/scale changes, and off-screen frames.
