# Phase 1 Manual Test Plan

## Safety rules

- Run capture and dictionary probes before any mutation probe.
- The lifecycle probe may close only the window object it created.
- Never run a blanket `close every window` command during Phase 1.
- Record the macOS and Finder versions with every result.

## Automated checks

```sh
swift build
swift test
swift run AswasFinderPoC dictionary
swift run AswasFinderPoC capture
swift run AswasFinderPoC accessibility
```

Expected baseline:

- The package builds with Swift 6 language checks.
- Dictionary output reports window APIs as present and `hasPublicTabModel` as false.
- Capture returns JSON and does not change Finder state.
- Accessibility reports either a clear permission boundary or a readable UI tree.

## Reversible window lifecycle

```sh
swift run AswasFinderPoC lifecycle "$PWD" --allow-window-mutation
```

Verify that:

1. Exactly one new Finder window appears.
2. It targets the requested directory.
3. Its frame changes to the requested bounds.
4. Its view changes to list view and is read back as list view.
5. The same new window closes and its ID is no longer enumerated.
6. All pre-existing Finder windows remain open.

## Tab investigation (permission-gated)

1. Create one Finder window with three tabs using Finder itself.
2. Put a distinct folder in each tab.
3. Select the middle tab.
4. Run the accessibility probe without permission and verify graceful denial.
5. If deliberately testing AX, grant Accessibility to the actual PoC host in System Settings.
6. Run the probe again and record whether `AXTabGroup` is present.
7. Inspect tab titles, order, selected state, and stable identifiers.
8. Revoke permission and verify the denial path again.

Do not adopt UI scripting in the product until this test passes on macOS 14 and the
current macOS release with both English and Chinese Finder UI.

## Remaining manual scenarios

- One and many Finder windows
- Unicode, spaces, iCloud, network, and external-volume paths
- Icon, list, column, and gallery views
- Finder restart during an operation
- Automation permission denied and later granted
- Left, right, and above secondary displays with negative coordinates
- Display removal and scale-factor changes
- Rapid repeated lifecycle/restore requests (after the serialized integration exists)
