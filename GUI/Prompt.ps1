# Give the user an interface to run options
Function Prompt {
    $Title = "Title"
    $Message = "What do you want to do?"
    $Get = New-Object System.Management.Automation.Host.ChoiceDescription "&Get", "Description."
    $Start = New-Object System.Management.Automation.Host.ChoiceDescription "&Start", "Description."
    $Kill = New-Object System.Management.Automation.Host.ChoiceDescription "&Kill", "Description."
    $Exit = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit", "Exits this utility."
    $Options = [System.Management.Automation.Host.ChoiceDescription[]]($Get, $Start, $Kill, $Exit)
    $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 

    Switch ($Result) {
        0 {'Getting services...'; break}
        1 {'Starting services...'; break}
        2 {'Stopping Services...'; break}
        3 {'Exiting...'; exit}
    }

    Prompt
}

Prompt