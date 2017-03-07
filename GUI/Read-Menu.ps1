$OldSQL = Read-Host 'Current SQL server'
$NewSQL = Read-Host 'New SQL server'
$DB = Read-Host 'Name of Database'

# Prompt the user whether they want to merge the database
Function Prompt {
	CLS
    $Title = "Database Backup Migration`n`n`tOLD SQL SERVER`t:`t$OldSQL`n`tNEW SQL SERVER`t:`t$NewSQL`n`tDATABASE`t:`t$DB"
    $Message = "`nDo you want to merge database?"
    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Perform a database merge on $DB, moving it from $OldSQL to $NewSQL."
    $No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", 'Exit this utility.'
    $Options = [System.Management.Automation.Host.ChoiceDescription[]]($Yes, $No)
    $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, 0) 
	CLS

    switch ($Result) {
        0 { 'Merging...'; Start-Sleep -Seconds 1; Break }
        1 { 'Exiting...'; Start-Sleep -Seconds 1; Exit }
    }

    Prompt
}

Prompt