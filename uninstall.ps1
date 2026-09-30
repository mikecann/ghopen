[CmdletBinding()]
param(
    [string]$ToolsDir = 'C:\dev\tools',
    [string]$ContextMenuBase = 'HKCU:\Software\Classes'
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Run uninstall.ps1 on Windows. On macOS, use uninstall.sh.' }

# Never remove the shared submenu or any sibling tool's verbs.
foreach ($folder in @('Directory', 'Directory\Background')) {
    $verb = "$ContextMenuBase\$folder\shell\MikesTools\shell\GhOpen"
    if (Test-Path -LiteralPath $verb) { Remove-Item -LiteralPath $verb -Recurse -Force }
}
foreach ($name in @('ghopen.bat', 'ghopen')) {
    $path = Join-Path $ToolsDir $name
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}
$icon = Join-Path $env:LOCALAPPDATA 'ghopen\icons\ghopen.ico'
if (Test-Path -LiteralPath $icon) { Remove-Item -LiteralPath $icon -Force }
Write-Host 'Removed ghopen stubs, icon and Explorer entries.' -ForegroundColor Green
