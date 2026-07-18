on closeWindowByID(windowIDText)
    set requestedID to windowIDText as integer
    try
        tell application "Finder"
            if exists window id requestedID then
                close window id requestedID
                return "{\"success\":true,\"found\":true}"
            end if
        end tell
        return "{\"success\":false,\"found\":false}"
    on error errorMessage number errorNumber
        return "{" & ¬
            "\"success\":false," & ¬
            "\"found\":true," & ¬
            "\"errorNumber\":" & errorNumber & "," & ¬
            "\"message\":\"" & my jsonEscape(errorMessage) & "\"" & ¬
            "}"
    end try
end closeWindowByID

on jsonEscape(value)
    set escapedValue to value as text
    set escapedValue to my replaceText(escapedValue, "\\", "\\\\")
    set escapedValue to my replaceText(escapedValue, "\"", "\\\"")
    set escapedValue to my replaceText(escapedValue, return, "\\n")
    set escapedValue to my replaceText(escapedValue, linefeed, "\\n")
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
