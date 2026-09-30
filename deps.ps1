# deps.ps1 for ghopen
# gh CLI is optional - ghopen falls back to parsing the remote URL manually.
# With gh installed, ghopen can open the current branch's PR.

if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "  [ghopen] gh CLI found: $(gh --version | Select-Object -First 1)" -ForegroundColor Green
} else {
    Write-Host "  [ghopen] gh CLI not found. ghopen will work, but with limited features." -ForegroundColor Yellow
    Write-Host "           Install it from https://cli.github.com/ for PR support." -ForegroundColor Yellow
}
