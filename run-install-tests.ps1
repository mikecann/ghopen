$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

# Parse every PowerShell file, including the test itself, before running helpers.
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -Filter '*.ps1') {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert-True ($parseErrors.Count -eq 0) "$($file.Name): $parseErrors"
}
Write-Host 'PowerShell parse checks passed'

. (Join-Path $PSScriptRoot 'install-lib.ps1')
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ghopen-tests-$([guid]::NewGuid())"
$registryBase = "HKCU:\Software\ghopen-tests-$([guid]::NewGuid())"
$originalLocalAppData = $env:LOCALAPPDATA

try {
    $toolsDir = Join-Path $testRoot 'bin with spaces'
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    Write-BatStub 'ghopen' '@echo off' $toolsDir
    foreach ($name in @('ghopen', 'ghopen.bat')) {
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $toolsDir $name))
        Assert-True (@($bytes | Where-Object { $_ -gt 127 }).Count -eq 0) "$name must be ASCII"
    }
    $shim = Get-Content -LiteralPath (Join-Path $toolsDir 'ghopen') -Raw
    Assert-True ($shim.Contains('exec "$SCRIPT_DIR/ghopen.bat" "$@"')) 'Git Bash shim must forward arguments'
    Assert-True (-not $shim.Contains("`r")) 'Git Bash shim must use LF line endings'

    $pngPath = Join-Path $PSScriptRoot 'icons/world_go.png'
    $icoPath = Join-Path $testRoot 'ghopen.ico'
    ConvertTo-Ico $pngPath $icoPath
    $pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
    $icoBytes = [System.IO.File]::ReadAllBytes($icoPath)
    Assert-True ($icoBytes.Length -eq $pngBytes.Length + 22) 'ICO must contain the complete PNG'
    Assert-True ([BitConverter]::ToUInt16($icoBytes, 2) -eq 1) 'ICO type must be an icon'
    Assert-True ([BitConverter]::ToUInt32($icoBytes, 18) -eq 22) 'ICO PNG offset must be 22'
    Assert-True ([Convert]::ToBase64String($icoBytes[22..($icoBytes.Length - 1)]) -eq [Convert]::ToBase64String($pngBytes)) 'ICO must preserve PNG bytes'
    Write-Host 'Stub and icon tests passed'

    if ($env:OS -eq 'Windows_NT') {
        # The real registry provider is used, but no Explorer keys are changed.
        $env:LOCALAPPDATA = $testRoot
        foreach ($folder in @('Directory', 'Directory\Background')) {
            $root = "$registryBase\$folder\shell\MikesTools"
            New-Item -Path "$root\shell\OtherTool\command" -Force | Out-Null
            Set-ItemProperty -LiteralPath $root -Name 'Icon' -Value 'shared.ico'
            Set-ItemProperty -LiteralPath "$root\shell\OtherTool\command" -Name '(Default)' -Value 'other-command'
        }
        & (Join-Path $PSScriptRoot 'install.ps1') -ToolsDir $toolsDir -ContextMenuBase $registryBase
        & (Join-Path $PSScriptRoot 'install.ps1') -ToolsDir $toolsDir -ContextMenuBase $registryBase -SkipDeps
        $stub = Get-Content -LiteralPath (Join-Path $toolsDir 'ghopen.bat') -Raw
        Assert-True ($stub.Contains("call `"$PSScriptRoot\ghopen.bat`" %*")) 'stub must point to this clone'
        foreach ($folder in @('Directory', 'Directory\Background')) {
            $root = "$registryBase\$folder\shell\MikesTools"
            $placeholder = if ($folder -eq 'Directory') { '%1' } else { '%V' }
            $command = (Get-ItemProperty -LiteralPath "$root\shell\GhOpen\command").'(Default)'
            Assert-True ($command -eq "cmd.exe /k `"cd /d `"$placeholder`" && `"$toolsDir\ghopen.bat`"`"") 'Explorer command must select the folder and call the stub'
            Assert-True ((Get-ItemProperty -LiteralPath $root).Icon -eq 'shared.ico') 'install must preserve shared menu icon'
        }
        Assert-True (Test-Path -LiteralPath (Join-Path $testRoot 'ghopen\icons\ghopen.ico')) 'install must generate icon'
        & (Join-Path $PSScriptRoot 'uninstall.ps1') -ToolsDir $toolsDir -ContextMenuBase $registryBase
        & (Join-Path $PSScriptRoot 'uninstall.ps1') -ToolsDir $toolsDir -ContextMenuBase $registryBase
        foreach ($name in @('ghopen', 'ghopen.bat')) {
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $toolsDir $name))) 'uninstall must remove stubs'
        }
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $testRoot 'ghopen\icons\ghopen.ico'))) 'uninstall must remove its icon'
        foreach ($folder in @('Directory', 'Directory\Background')) {
            $root = "$registryBase\$folder\shell\MikesTools"
            Assert-True (-not (Test-Path -LiteralPath "$root\shell\GhOpen")) 'uninstall must remove GhOpen verb'
            Assert-True ((Get-ItemProperty -LiteralPath "$root\shell\OtherTool\command").'(Default)' -eq 'other-command') 'install and uninstall must preserve sibling verbs'
            Assert-True ((Get-ItemProperty -LiteralPath $root).MUIVerb -eq "Mike's Tools") 'uninstall must preserve shared menu'
        }
        Write-Host 'Windows registry install/uninstall tests passed'
    } else {
        Write-Host 'Windows registry integration tests skipped on this platform'
    }
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    if ($env:OS -eq 'Windows_NT' -and (Test-Path -LiteralPath $registryBase)) {
        Remove-Item -LiteralPath $registryBase -Recurse -Force
    }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
