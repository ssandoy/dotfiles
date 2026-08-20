param(
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$Body = ""
)
Import-Module BurntToast
New-BurntToastNotification -Text $Title, $Body
