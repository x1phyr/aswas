on run arguments
    if (count arguments) is 0 then error "A target folder path is required."

    set targetPath to item 1 of arguments
    set createdWindow to missing value

    try
        tell application "Finder"
            set targetFolder to (POSIX file targetPath as alias)
            set createdWindow to make new Finder window to targetFolder
            set createdID to id of createdWindow
            set bounds of createdWindow to {160, 160, 960, 760}
            set current view of createdWindow to list view
            delay 0.25

            set capturedPath to POSIX path of (target of createdWindow as alias)
            set capturedBounds to bounds of createdWindow
            set capturedView to my normalizedViewName((current view of createdWindow) as text)
            close createdWindow
            set remainingWindowIDs to id of every window
            set createdWindowWasClosed to createdID is not in remainingWindowIDs
        end tell

        return "{" & ¬
            "\"success\":true," & ¬
            "\"createdWindowID\":" & createdID & "," & ¬
            "\"path\":\"" & my jsonEscape(capturedPath) & "\"," & ¬
            "\"bounds\":[" & my boundsJSON(capturedBounds) & "]," & ¬
            "\"viewMode\":\"" & capturedView & "\"," & ¬
            "\"closedCreatedWindow\":" & my booleanJSON(createdWindowWasClosed) & ¬
            "}"
    on error errorMessage number errorNumber
        if createdWindow is not missing value then
            try
                tell application "Finder" to close createdWindow
            end try
        end if

        return "{" & ¬
            "\"success\":false," & ¬
            "\"errorNumber\":" & errorNumber & "," & ¬
            "\"message\":\"" & my jsonEscape(errorMessage) & "\"" & ¬
            "}"
    end try
end run

on booleanJSON(value)
    if value then return "true"
    return "false"
end booleanJSON

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
