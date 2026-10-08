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

# ghopen.bat's no-gh fallback hands the URL to Start-Process, which would also run a program or
# open a local file. Only remotes that point exactly at github.com may come out the other end.
$openRemote = Join-Path $PSScriptRoot 'open-remote.ps1'
$shells = @((Get-Process -Id $PID).Path)
if ($env:OS -eq 'Windows_NT') { $shells += 'powershell.exe' } # ghopen.bat runs Windows PowerShell 5.1
function Invoke-OpenRemote([string]$Shell, [string]$Remote) {
    $previous = $env:REMOTE
    $env:REMOTE = $Remote
    try {
        $output = & $Shell -NoProfile -ExecutionPolicy Bypass -File $openRemote -PrintOnly 2>$null
        return @{ Output = "$output"; Status = $LASTEXITCODE }
    } finally { $env:REMOTE = $previous }
}
$accepted = @{
    'git@github.com:mike/repo.git' = 'https://github.com/mike/repo'
    'ssh://git@github.com/mike/repo.git' = 'https://github.com/mike/repo'
    'https://github.com/mike/repo' = 'https://github.com/mike/repo'
    'http://github.com/mike/my.repo/' = 'https://github.com/mike/my.repo'
    'git://github.com/mike-c/repo_1.git' = 'https://github.com/mike-c/repo_1'
    # Some credential setups put a user or token before the host. It's dropped, never opened.
    'https://token@github.com/mike/repo.git' = 'https://github.com/mike/repo'
    'https://mike:secret@github.com/mike/repo' = 'https://github.com/mike/repo'
}
$rejected = @(
    '',
    'git@gitlab.com:mike/repo.git',
    'https://github.com.example.com/mike/repo',
    'https://example.com/github.com/mike/repo',
    'https://github.com@example.com/mike/repo',
    'https://token@github.com.example.com/mike/repo',
    'ssh://token@github.com/mike/repo',
    'file:///C:/github.com/tool.exe',
    'C:\github.com\tool.exe',
    '..\github.com\tool.cmd',
    'https://github.com/mike/repo/../../../tool.exe',
    'https://github.com/mike/repo" & calc & "'
)
foreach ($shell in $shells) {
    foreach ($remote in $accepted.Keys) {
        $result = Invoke-OpenRemote $shell $remote
        Assert-True ($result.Status -eq 0 -and $result.Output -eq $accepted[$remote]) "$shell should open $($accepted[$remote]) for $remote, got '$($result.Output)' ($($result.Status))"
    }
    foreach ($remote in $rejected) {
        $result = Invoke-OpenRemote $shell $remote
        Assert-True ($result.Status -eq 1 -and $result.Output -eq '') "$shell should reject '$remote', got '$($result.Output)' ($($result.Status))"
    }
}
Write-Host 'GitHub remote fallback tests passed'

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

        # Run ghopen.bat itself with gh hidden from PATH, so cmd's handling of the remote is
        # covered too. Only remotes that get rejected are used, so nothing is opened.
        $repo = Join-Path $testRoot 'bat repo'
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        git -C $repo init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
        $noGhPath = @(
            (Split-Path (Get-Command git).Source),
            (Join-Path $env:SystemRoot 'System32'),
            (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0')
        ) -join ';'
        function Invoke-GhopenBat {
            $info = New-Object System.Diagnostics.ProcessStartInfo
            $info.FileName = Join-Path $env:SystemRoot 'System32\cmd.exe'
            # cmd strips the outer quotes and runs: "<clone>\ghopen.bat" 2>&1
            $info.Arguments = "/d /c `"`"$(Join-Path $PSScriptRoot 'ghopen.bat')`" 2>&1`""
            $info.WorkingDirectory = $repo
            $info.UseShellExecute = $false
            $info.RedirectStandardOutput = $true
            $info.EnvironmentVariables['PATH'] = $noGhPath
            $info.EnvironmentVariables.Remove('REMOTE')
            $process = [System.Diagnostics.Process]::Start($info)
            $output = $process.StandardOutput.ReadToEnd()
            $process.WaitForExit()
            return @{ Output = $output; Status = $process.ExitCode }
        }
        $result = Invoke-GhopenBat
        Assert-True ($result.Status -eq 1 -and $result.Output.Contains('No origin remote found.')) "ghopen.bat without origin, got '$($result.Output)' ($($result.Status))"
        # A remote that closes the quotes. If cmd ever expanded it, PWNED would be echoed on its own line.
        # It's written straight into .git\config so no shell gets a chance to re-quote it.
        $hostile = 'https://x" & echo PWNED & "'
        Add-Content -LiteralPath (Join-Path $repo '.git\config') -Value ("[remote `"origin`"]`n`turl = " + $hostile.Replace('"', '\"'))
        Assert-True ((git -C $repo remote get-url origin) -eq $hostile) 'test remote must round-trip through git config'
        $result = Invoke-GhopenBat
        Assert-True ($result.Status -eq 1 -and $result.Output.Contains('Not a GitHub remote') -and $result.Output -notmatch '(?m)^\s*PWNED\s*$') "ghopen.bat must reject the remote without running it, got '$($result.Output)' ($($result.Status))"
        Write-Host 'ghopen.bat fallback tests passed'
    } else {
        Write-Host 'Windows registry and ghopen.bat integration tests skipped on this platform'
    }
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    if ($env:OS -eq 'Windows_NT' -and (Test-Path -LiteralPath $registryBase)) {
        Remove-Item -LiteralPath $registryBase -Recurse -Force
    }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
