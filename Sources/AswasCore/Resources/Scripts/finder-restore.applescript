on restoreWindow(targetPath, leftText, topText, rightText, bottomText, requestedView)
    set createdWindow to missing value
    try
        tell application "Finder"
            set targetFolder to (POSIX file targetPath as alias)
            set createdWindow to make new Finder window to targetFolder
            set createdID to id of createdWindow

            set frameWasRestored to true
            if leftText is not "" then
                try
                    set bounds of createdWindow to {leftText as integer, topText as integer, rightText as integer, bottomText as integer}
                on error
                    set frameWasRestored to false
                end try
            end if

            set viewWasRestored to true
            try
                if requestedView is "icon" then
                    set current view of createdWindow to icon view
                else if requestedView is "list" then
                    set current view of createdWindow to list view
                else if requestedView is "column" then
                    set current view of createdWindow to column view
                else if requestedView is "gallery" then
                    set current view of createdWindow to flow view
                else
                    set viewWasRestored to false
                end if
            on error
                set viewWasRestored to false
            end try
        end tell

        return "{" & ¬
            "\"success\":true," & ¬
            "\"windowID\":" & createdID & "," & ¬
            "\"frameRestored\":" & my booleanJSON(frameWasRestored) & "," & ¬
            "\"viewModeRestored\":" & my booleanJSON(viewWasRestored) & ¬
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
end restoreWindow

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
