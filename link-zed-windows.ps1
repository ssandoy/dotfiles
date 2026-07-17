param(
  [Parameter(Mandatory = $true)]
  [string]$Source
)

$ErrorActionPreference = "Stop"
$Target = Join-Path $env:APPDATA "Zed"
$Names = @("settings.json", "keymap.json")

New-Item -ItemType Directory -Force -Path $Target | Out-Null

foreach ($Name in $Names) {
  $Src = Join-Path $Source $Name
  $Dst = Join-Path $Target $Name

  if (!(Test-Path -LiteralPath $Src)) {
    throw "Missing source file: $Src"
  }

  if (Test-Path -LiteralPath $Dst) {
    $Existing = Get-Item -LiteralPath $Dst -Force
    if ($Existing.LinkType -eq "SymbolicLink") {
      Remove-Item -LiteralPath $Dst -Force
    } else {
      $Backup = "$Dst.backup-$(Get-Date -Format yyyyMMddHHmmss)"
      Copy-Item -LiteralPath $Dst -Destination $Backup -Force
      Remove-Item -LiteralPath $Dst -Force
      Write-Host "Backed up $Dst to $Backup"
    }
  }

  try {
    New-Item -ItemType SymbolicLink -Path $Dst -Target $Src -Force -ErrorAction Stop | Out-Null
    Write-Host "Linked $Dst -> $Src"
  } catch {
    Copy-Item -LiteralPath $Src -Destination $Dst -Force
    Write-Host "Copied $Src to $Dst because creating a Windows symlink failed"
  }
}
