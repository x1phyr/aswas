on run
    try
        tell application "Finder"
            if (count windows) is 0 then error "Finder has no readable front window." number -1728
            set windowReference to front window
            return my windowJSON(windowReference)
        end tell
    on error errorMessage number errorNumber
        error errorMessage number errorNumber
    end try
end run

on setFrontWindowTarget(targetPath)
    try
        tell application "Finder"
            if (count windows) is 0 then error "Finder has no readable front window." number -1728
            set target of front window to (POSIX file targetPath as alias)
        end tell
        return "{\"success\":true}"
    on error errorMessage number errorNumber
        return "{" & ¬
            "\"success\":false," & ¬
            "\"errorNumber\":" & errorNumber & "," & ¬
            "\"message\":\"" & my jsonEscape(errorMessage) & "\"" & ¬
            "}"
    end try
end setFrontWindowTarget

on windowJSON(windowReference)
    tell application "Finder"
        set windowID to id of windowReference
        set windowIndex to index of windowReference
        set windowName to name of windowReference
        set windowBounds to bounds of windowReference
        set windowPath to POSIX path of (target of windowReference as alias)
        set windowView to my normalizedViewName((current view of windowReference) as text)
    end tell

    return "{" & ¬
        "\"id\":" & windowID & "," & ¬
        "\"index\":" & windowIndex & "," & ¬
        "\"name\":\"" & my jsonEscape(windowName) & "\"," & ¬
        "\"path\":\"" & my jsonEscape(windowPath) & "\"," & ¬
        "\"bounds\":[" & my boundsJSON(windowBounds) & "]," & ¬
        "\"viewMode\":\"" & windowView & "\"" & ¬
        "}"
end windowJSON

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
