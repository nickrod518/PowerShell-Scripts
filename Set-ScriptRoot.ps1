# Set ScripRoot variable to the path which the script is executed from
$ScriptRoot = if ($PSVersionTable.PSVersion.Major -lt 3) {
    Split-Path -Path $MyInvocation.MyCommand.Path
} else {
    $PSScriptRoot
}