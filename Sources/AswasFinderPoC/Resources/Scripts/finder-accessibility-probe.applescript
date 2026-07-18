on run
    tell application "System Events"
        set accessibilityEnabled to UI elements enabled
    end tell

    if accessibilityEnabled is false then
        return "{" & ¬
            "\"accessibilityGranted\":false," & ¬
            "\"finderWindowsReadable\":false," & ¬
            "\"tabGroupDetected\":false," & ¬
            "\"message\":\"Accessibility permission is not granted; no Finder UI was inspected.\"" & ¬
            "}"
    end if

    try
        tell application "System Events"
            tell process "Finder"
                set finderWindowCount to count windows
                set tabGroupCount to 0

                if finderWindowCount is greater than 0 then
                    set finderElements to entire contents of front window
                    repeat with elementReference in finderElements
                        try
                            if role of elementReference is "AXTabGroup" then
                                set tabGroupCount to tabGroupCount + 1
                            end if
                        end try
                    end repeat
                end if
            end tell
        end tell

        return "{" & ¬
            "\"accessibilityGranted\":true," & ¬
            "\"finderWindowsReadable\":true," & ¬
            "\"finderWindowCount\":" & finderWindowCount & "," & ¬
            "\"tabGroupDetected\":" & my booleanJSON(tabGroupCount is greater than 0) & "," & ¬
            "\"tabGroupCount\":" & tabGroupCount & ¬
            "}"
    on error errorMessage number errorNumber
        return "{" & ¬
            "\"accessibilityGranted\":true," & ¬
            "\"finderWindowsReadable\":false," & ¬
            "\"tabGroupDetected\":false," & ¬
            "\"errorNumber\":" & errorNumber & "," & ¬
            "\"message\":\"" & my jsonEscape(errorMessage) & "\"" & ¬
            "}"
    end try
end run

on booleanJSON(value)
    if value then return "true"
    return "false"
end booleanJSON

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
