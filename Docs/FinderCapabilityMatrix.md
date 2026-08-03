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
| Read tabs | Best effort, permission-gated | AX physical windows + AppleScript entries | Finder exposes each tab as a window-like entry and may leave inactive entries at stale bounds after a move. AX windows and `AXTabs` define groups; the selected tab's live frame anchors path matching. |
| Read selected tab | Best effort, permission-gated | AX value | The selected AX tab is recorded when the physical window and tab strip are matched successfully. |
| Read tab order | Best effort, permission-gated | `AXTabs` order + title matching | AX is read-only during capture. Duplicate Finder titles remain ambiguous and are rejected when bounds cannot disambiguate them. |
| Create tabs | Best effort, permission-gated | Accessibility keyboard event + AppleScript `target` | Additional tabs are requested serially with a stabilization delay. Posting Command-T does not itself prove that Finder created a tab. |
| Restore tab order | Best effort, permission-gated | Sequential UI automation | The current AX target is chosen primarily by frame; overlapping windows require additional identity verification. |
| Restore selected tab | Enhanced, permission-gated | AX press | Falls back with a partial-restore warning if selection fails. |
| Accessibility UI inspection | Permission required for multi-tab fidelity | AXUIElement | Requested explicitly in Settings. Single-tab windows remain usable without it; detected multi-tab saves are rejected rather than flattened. |
| Multi-display placement | Unverified | AppleScript + AppKit | Requires coordinate conversion tests with multiple display arrangements. |

## Current conclusion

AppleScript remains the reliable window-level baseline. Multi-tab fidelity is attempted
as an explicitly permission-gated enhancement using AXUIElement for the tab strip and
AppleScript for exact folder paths. If Accessibility is unavailable or Finder's UI changes,
aswas refuses to persist or overwrite a multi-tab snapshot when AX metadata is absent,
preserving the previous workspace and leaving all Finder windows open. Duplicate tab titles,
Finder focus races, and overlapping-window restore targeting remain
known hardening areas and must be included in release testing.
