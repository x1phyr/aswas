# Finder Capability Matrix

Environment initially tested: macOS 26.5.2 (25F84), Finder 26.4, Xcode 26.6, and
Swift 6.3.3. The deployment target remains macOS 14; this result must not be treated as
proof of behavior on every supported OS release.

| Capability | Status | Method | Evidence / limitation |
| --- | --- | --- | --- |
| List Finder windows | Supported | AppleScript | Live probe enumerated existing Finder windows. |
| Read current folder | Supported | AppleScript `target` | Live probe returned POSIX paths, including Unicode paths. Special locations can still fail and must become warnings. |
| Read window bounds | Supported | AppleScript `bounds` | Live probe returned four-coordinate rectangles. Coordinate mapping to AppKit remains unverified. |
| Restore window bounds | Supported | In-process AppleScript `bounds` | Native restore created a window at the requested bounds and returned its ID. |
| Read view mode | Supported | AppleScript `current view` | Icon and list views were observed. Gallery/group naming requires more testing. |
| Restore view mode | Supported for list view | AppleScript `current view` | The PoC-created window accepted `list view` and reported it back. Icon, column, and gallery still need individual coverage. |
| Create a Finder window | Supported | In-process AppleScript `make new Finder window` | Native restore created a window targeting the repository folder. |
| Close a specified window | Supported | In-process AppleScript `close window id` | Native cleanup closed only the returned window ID; the first loop-specifier attempt exposed error -1731 and was replaced. |
| Read tabs | Not available in public dictionary | Accessibility candidate | Finder `sdef` contains no public tab class, element, or property. |
| Read selected tab | Unverified | Accessibility candidate | Blocked until a deliberately authorized AX probe can inspect a tabbed Finder window. |
| Read tab order | Unverified | Accessibility candidate | Same limitation; UI ordering may be OS-version-sensitive. |
| Create tabs | Unverified | UI Scripting candidate | Would require Accessibility and UI actions; not promised for MVP yet. |
| Restore tab order | Unverified | UI Scripting candidate | No public AppleScript API. Must be best effort if UI scripting is viable. |
| Restore selected tab | Unverified | UI Scripting candidate | No public AppleScript API. |
| Accessibility UI inspection | Permission required | System Events / AXUIElement | Current probe reported Accessibility disabled and correctly avoided inspecting Finder UI. |
| Multi-display placement | Unverified | AppleScript + AppKit | Requires coordinate conversion tests with multiple display arrangements. |

## Current conclusion

AppleScript is sufficient for the window-level MVP baseline: enumerate windows, capture
the main directory, capture/restore bounds, capture view mode, create windows, and close
precisely tracked windows. Finder tabs cannot be claimed as supported from the public
dictionary. They remain an explicitly isolated, permission-gated best-effort track.
