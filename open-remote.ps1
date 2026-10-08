# ghopen.bat runs this when the GitHub CLI isn't installed. It opens origin's page on GitHub.
#
# Start-Process would just as happily run a program or open a local file as a web page, so the
# remote is never passed through. Only remotes that point exactly at github.com are accepted,
# and the page is rebuilt as https://github.com/owner/repo, like the macOS ghopen does.
#
# The remote comes from the REMOTE environment variable so cmd never expands it.
param(
    [string]$Remote = $env:REMOTE,
    # Print the URL instead of opening it. Used by run-install-tests.ps1.
    [switch]$PrintOnly
)

# Some credential setups write https://user@github.com/... or https://user:token@github.com/...
# The page never needs that part, so drop it (and keep it out of the error message too).
$Remote = $Remote -replace '^(https?://)[^@/]*@', '$1'

$prefixes = @('git@github.com:', 'ssh://git@github.com/', 'https://github.com/', 'http://github.com/', 'git://github.com/')
$repoPath = $null
foreach ($prefix in $prefixes) {
    if ($Remote.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $repoPath = ($Remote.Substring($prefix.Length) -replace '/$', '') -replace '\.git$', ''
        break
    }
}

if ($null -eq $repoPath -or $repoPath -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    [Console]::Error.WriteLine("Not a GitHub remote: $Remote")
    exit 1
}

$url = "https://github.com/$repoPath"
if ($PrintOnly) {
    Write-Output $url
} else {
    Start-Process $url
}
exit 0
