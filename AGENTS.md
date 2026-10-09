# Agent guidance for ghopen

`ghopen` opens the current GitHub repo or its pull request in a browser. This repo supports Windows and macOS; all source and scripts live at the repo root.

## Key rules

- Keep the command name `ghopen`.
- Never put source files directly in `C:\dev\tools`. That directory holds only generated stubs and any separately installed large binaries. Keep logic in this clone.
- Never commit `.exe` or `.dll` binaries.
- Use test-first development for non-trivial changes. Write or update the relevant test, then implement until it passes. Extract a test seam first if needed.
- When behaviour or tested expectations change, update and rerun the affected tests in the same change.
- Test before committing: run `bash run-tests.sh`, `bash run-install-tests.sh` and `pwsh -NoProfile -File ./run-install-tests.ps1`. On Windows, smoke-test `ghopen.bat` from a real checkout and both Explorer menu entries. Check exit codes.
- Keep `.bat` files ASCII. Use `-Encoding ASCII` when generating them in PowerShell.
- Re-run this repo's `install.ps1` or `install.sh` when installer integration changes or the clone moves. Editing the command itself doesn't require reinstalling because stubs and symlinks point to the live source.
- Keep the shared `Mike's Tools` submenu. Install and uninstall must preserve other tools' verbs and existing submenu properties.

## Dependencies

`deps.ps1` checks for the optional GitHub CLI. Keep it idempotent, self-contained and runnable directly with `powershell -NoProfile -File .\deps.ps1`. Use `Get-Command` to detect system tools and clear coloured output when a dependency is missing. The Windows installer runs it unless `-SkipDeps` is given.

## Implementation

- `ghopen` is the Bash launcher. It tries `gh pr view --web`, then `gh browse`, then parses `origin` and uses `open` or `xdg-open`. `GHOPEN_OPEN_COMMAND` can override the opener.
- `ghopen.bat` is the Windows implementation. It tries the PR first, then `gh browse`. Without `gh`, it passes `origin` to `open-remote.ps1` through the `REMOTE` environment variable. That script drops any `user@` or `user:token@` from an HTTPS remote, only accepts remotes that point exactly at github.com, and opens the rebuilt `https://github.com/owner/repo` URL, because `Start-Process` would also run a program or open a local file. Never expand the remote with `%REMOTE%` in the batch file. `run-install-tests.ps1` runs `ghopen.bat` on Windows with `gh` hidden and a remote that tries to break out of cmd's quotes.
- `install.ps1` writes `ghopen.bat` and an extensionless Git Bash shim to `C:\dev\tools`, converts `icons/world_go.png` to `%LOCALAPPDATA%\ghopen\icons\ghopen.ico`, and registers `GhOpen` under the per-user folder and folder-background `MikesTools` menus.
- `install-lib.ps1` contains only the helpers needed for those integrations.
- `install.sh` installs a symlink into `~/.local/bin` or a supplied destination. `setup_mac.sh` delegates to it for compatibility.
- This is a CLI tool. It deliberately keeps a console open when launched from Explorer so errors remain visible.
- No secrets or `.env` file are required. Authentication belongs to the GitHub CLI.

## Writing

Use plain, friendly language and first person for Mike's opinions. Avoid em dashes and en dashes. Keep README installation steps relative to this clone.
