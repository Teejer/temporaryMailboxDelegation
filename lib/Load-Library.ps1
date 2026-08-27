<#
.SYNOPSIS
    Dot-sources every helper function from the lib folder.
.NOTES
    Run this FIRST from your main scripts:  . "$PSScriptRoot\lib\Load-Library.ps1"
#>
[CmdletBinding()]
param()

$files = Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' |
    Where-Object { $_.Name -ne 'Load-Library.ps1' }

foreach ($file in $files) {
    . $file.FullName
}
