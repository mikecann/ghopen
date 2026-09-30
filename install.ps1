[CmdletBinding()]
param(
    [switch]$SkipDeps,
    [string]$ToolsDir = 'C:\dev\tools',
    [string]$ContextMenuBase = 'HKCU:\Software\Classes'
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Run install.ps1 on Windows. On macOS, use install.sh.' }
. (Join-Path $PSScriptRoot 'install-lib.ps1')

New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
$content = @"
@echo off
call "$PSScriptRoot\ghopen.bat" %*
"@
Write-BatStub 'ghopen' $content $ToolsDir
Write-Host "Installed ghopen stubs to $ToolsDir" -ForegroundColor Green

$iconsDir = Join-Path $env:LOCALAPPDATA 'ghopen\icons'
New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null
$icon = Join-Path $iconsDir 'ghopen.ico'
ConvertTo-Ico (Join-Path $PSScriptRoot 'icons\world_go.png') $icon

$dirRoot = "$ContextMenuBase\Directory\shell\MikesTools"
$bgRoot = "$ContextMenuBase\Directory\Background\shell\MikesTools"
Set-MikesToolsRoot $dirRoot
Set-MikesToolsRoot $bgRoot
Add-MikesVerb $dirRoot 'GhOpen' 'Open on GitHub' $icon "cmd.exe /k `"cd /d `"%1`" && `"$ToolsDir\ghopen.bat`"`""
Add-MikesVerb $bgRoot 'GhOpen' 'Open on GitHub' $icon "cmd.exe /k `"cd /d `"%V`" && `"$ToolsDir\ghopen.bat`"`""
Write-Host "Added Open on GitHub to Mike's Tools for folders and folder backgrounds." -ForegroundColor Green

if (-not $SkipDeps) { & (Join-Path $PSScriptRoot 'deps.ps1') }
Write-Host "Add $ToolsDir to PATH if it is not already there. Re-run this installer after moving the clone." -ForegroundColor Yellow
