on run
    set capturedWindows to {}
    set captureWarnings to {}

    tell application "Finder"
        set windowList to every window

        repeat with windowReference in windowList
            try
                set windowID to id of windowReference
                set windowIndex to index of windowReference
                set windowName to name of windowReference
                set windowBounds to bounds of windowReference
                set windowPath to POSIX path of (target of windowReference as alias)
                set windowView to my normalizedViewName((current view of windowReference) as text)

                set windowJSON to "{" & ¬
                    "\"id\":" & windowID & "," & ¬
                    "\"index\":" & windowIndex & "," & ¬
                    "\"name\":\"" & my jsonEscape(windowName) & "\"," & ¬
                    "\"path\":\"" & my jsonEscape(windowPath) & "\"," & ¬
                    "\"bounds\":[" & my boundsJSON(windowBounds) & "]," & ¬
                    "\"viewMode\":\"" & windowView & "\"" & ¬
                    "}"
                set end of capturedWindows to windowJSON
            on error errorMessage number errorNumber
                set warningJSON to "{" & ¬
                    "\"code\":\"windowUnreadable\"," & ¬
                    "\"errorNumber\":" & errorNumber & "," & ¬
                    "\"message\":\"" & my jsonEscape(errorMessage) & "\"" & ¬
                    "}"
                set end of captureWarnings to warningJSON
            end try
        end repeat
    end tell

    return "{" & ¬
        "\"schemaVersion\":1," & ¬
        "\"windows\":[" & my joinText(capturedWindows, ",") & "]," & ¬
        "\"warnings\":[" & my joinText(captureWarnings, ",") & "]" & ¬
        "}"
end run

on normalizedViewName(viewName)
    if viewName is "icon view" then return "icon"
    if viewName is "list view" then return "list"
    if viewName is "column view" then return "column"
    if viewName is "flow view" or viewName is "group view" then return "gallery"
    return "unknown"
end normalizedViewName

on boundsJSON(windowBounds)
    return ((item 1 of windowBounds) as text) & "," & ¬
        ((item 2 of windowBounds) as text) & "," & ¬
        ((item 3 of windowBounds) as text) & "," & ¬
        ((item 4 of windowBounds) as text)
end boundsJSON

on joinText(values, separator)
    if (count values) is 0 then return ""
    set previousDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to separator
    set joinedText to values as text
    set AppleScript's text item delimiters to previousDelimiters
    return joinedText
end joinText

on jsonEscape(value)
    set escapedValue to value as text
    set escapedValue to my replaceText(escapedValue, "\\", "\\\\")
    set escapedValue to my replaceText(escapedValue, "\"", "\\\"")
    set escapedValue to my replaceText(escapedValue, return, "\\n")
    set escapedValue to my replaceText(escapedValue, linefeed, "\\n")
    set escapedValue to my replaceText(escapedValue, tab, "\\t")
    return escapedValue
end jsonEscape

on replaceText(value, searchText, replacementText)
    set previousDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to searchText
    set valueParts to text items of value
    set AppleScript's text item delimiters to replacementText
    set replacedValue to valueParts as text
    set AppleScript's text item delimiters to previousDelimiters
    return replacedValue
end replaceText
