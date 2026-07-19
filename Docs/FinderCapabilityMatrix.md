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
| Read tabs | Supported | AppleScript entries + window grouping | Finder exposes each tab as a window-like entry. Entries sharing physical bounds are grouped without switching or modifying tabs. |
| Read selected tab | Enhanced, permission-gated | AX value | The selected AX tab is recorded and restored after capture. |
| Read tab order | Enhanced, permission-gated | AX child order | AX is read-only during capture. A multi-tab save is rejected if reliable order is unavailable. |
| Create tabs | Enhanced, permission-gated | Accessibility keyboard event + AppleScript `target` | Additional tabs are created serially with a stabilization delay. |
| Restore tab order | Enhanced, permission-gated | Sequential UI automation | Failures are isolated per path and reported. |
| Restore selected tab | Enhanced, permission-gated | AX press | Falls back with a partial-restore warning if selection fails. |
| Accessibility UI inspection | Permission required | AXUIElement | Requested explicitly in Settings; the window-only workflow remains available without it. |
| Multi-display placement | Unverified | AppleScript + AppKit | Requires coordinate conversion tests with multiple display arrangements. |

## Current conclusion

AppleScript remains the reliable window-level baseline. Full tab fidelity is implemented
as an explicitly permission-gated enhancement using AXUIElement for the tab strip and
AppleScript for exact folder paths. If Accessibility is unavailable or Finder's UI changes,
aswas refuses to persist or overwrite a multi-tab snapshot, preserving the previous reliable
workspace and leaving all Finder windows open.
