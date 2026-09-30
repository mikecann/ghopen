function Write-BatStub {
    param([string]$ToolName, [string]$Content, [string]$ToolsDir)

    Set-Content -LiteralPath (Join-Path $ToolsDir "$ToolName.bat") -Value $Content -Encoding ASCII
    # Git Bash needs an extensionless launcher as well as the CMD stub.
    $bashContent = @'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/__TOOL_NAME__.bat" "$@"
'@.Replace("__TOOL_NAME__", $ToolName)
    # A CRLF shebang fails when Git Bash executes this launcher directly.
    [System.IO.File]::WriteAllText((Join-Path $ToolsDir $ToolName), $bashContent.Replace("`r`n", "`n") + "`n", [System.Text.Encoding]::ASCII)
}

function ConvertTo-Ico($pngPath, $icoPath) {
    # PNG-in-ICO preserves the source icon's alpha channel on Vista and later.
    $pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
    $stream = [System.IO.FileStream]::new($icoPath, [System.IO.FileMode]::Create)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
        $writer.Write([byte]16); $writer.Write([byte]16); $writer.Write([byte]0)
        $writer.Write([byte]0); $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$pngBytes.Length); $writer.Write([uint32]22)
        $writer.Write($pngBytes)
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function Set-MikesToolsRoot($rootKey) {
    if (-not (Test-Path -LiteralPath $rootKey)) {
        New-Item -Path $rootKey -Force | Out-Null
    }
    # Other standalone tools share this submenu. Preserve its properties and verbs.
    $properties = Get-ItemProperty -LiteralPath $rootKey
    if ($null -eq $properties.MUIVerb) {
        Set-ItemProperty -LiteralPath $rootKey -Name 'MUIVerb' -Value "Mike's Tools"
    }
    if ($null -eq $properties.SubCommands) {
        Set-ItemProperty -LiteralPath $rootKey -Name 'SubCommands' -Value ''
    }
}

function Add-MikesVerb($rootKey, $verbName, $label, $icon, $command) {
    $verbKey = "$rootKey\shell\$verbName"
    $cmdKey = "$verbKey\command"
    if (-not (Test-Path -LiteralPath $cmdKey)) {
        New-Item -Path $cmdKey -Force | Out-Null
    }
    Set-ItemProperty -LiteralPath $verbKey -Name 'MUIVerb' -Value $label
    Set-ItemProperty -LiteralPath $verbKey -Name 'Icon' -Value $icon
    Set-ItemProperty -LiteralPath $cmdKey -Name '(Default)' -Value $command
}
