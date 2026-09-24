# Windows

`install.sh` is bash and it builds a tree of symlinks, so it is written for macOS
and Linux. This page covers the two ways to get the kit onto a Windows machine.

**None of this has been run on Windows.** The author has no Windows machine. The
WSL route is ordinary Linux and should just work; the native route is reasoned
from what the files do, not observed, and the parts that are genuinely unknown are
marked as such. The "Expect" lines after each command are what should happen, not
what was seen. Corrections are welcome as issues — see
[CONTRIBUTING.md](../CONTRIBUTING.md).

## Which route

| | WSL | Native Windows |
|---|---|---|
| effort | one command | manual, ~15 minutes |
| `install.sh` | works as-is | not usable |
| hooks | work | **unknown** — see below |
| sandbox | as on Linux | **unknown** |
| recommendation | **use this** | only if WSL is not an option |

The deciding question for the native route is whether Claude Code on Windows can
run `bash ~/.claude/hooks/whatever.sh`. Every hook in this kit is a bash script,
and `settings.json` invokes them that way. If your Windows Claude Code resolves
`bash` (Git for Windows puts one on `PATH`), the hooks should run. If it does not,
they fail silently-ish and you are left with the config but none of the guardrails
— which is the part worth checking first.

## WSL (recommended)

In PowerShell, skipping this if you already have a distro:

```powershell
wsl --install
```

Expect: WSL and a default Ubuntu distro install, then Windows asks to restart. After
the restart, open the distro from the Start menu and create its Linux user.

Two things that bite from here on:

- **Clone inside the WSL filesystem** (`~/…`), not under `/mnt/c/…`. The Windows
  mount does not carry Unix permissions or symlinks properly, and `install.sh`
  builds a tree of symlinks. Running it under `/mnt/c` is the single most likely
  way to get a broken install.
- **Run Claude Code from inside WSL too.** A Windows-side Claude Code reads
  `C:\Users\you\.claude`, not the `~/.claude` you are about to populate. They are
  different homes; installing in one and running in the other looks like the
  install silently did nothing.

If you run `install.sh` from Git Bash, MSYS or Cygwin, it stops and prints this
same advice rather than half-installing.

Inside WSL, install `jq` (the hooks parse their input with it) and `git`:

```bash
sudo apt install jq git
```

Expect: apt installs both, or reports that each is already the newest version.

Inside WSL, replace `<you>` before pasting:

```bash
cd ~ && git clone https://github.com/<you>/nimbrail.git && cd nimbrail && ./install.sh
```

Expect: the clone finishes and `install.sh` opens by asking which language to run in
(English / 日本語). From there it is the same install as on Linux.

## Native Windows (manual, untested)

Do by hand what `install.sh` does. Paths below assume `%USERPROFILE%` is your home
and `REPO` is your clone.

Symlinks need Developer Mode on, or an elevated shell. If neither is available,
copy instead of linking — everything still works, but edits in the repo no longer
reach `~/.claude` and you have to re-copy after every `git pull`.

Set the two paths. Replace `C:\path\to\nimbrail` with your clone before pasting:

```powershell
$claude = "$env:USERPROFILE\.claude"; $repo = "C:\path\to\nimbrail"
```

Expect: nothing is printed. Then check that both took:

```powershell
Test-Path "$repo\install.sh"; $claude
```

Expect: `True`, then your `.claude` path. `False` means `$repo` does not point at the
clone — set it again before going on.

Create the directories and the links:

```powershell
New-Item -ItemType Directory -Force "$claude\hooks", "$claude\skills" | Out-Null
New-Item -ItemType SymbolicLink -Path "$claude\CLAUDE.md"     -Target "$repo\config\CLAUDE.md"
New-Item -ItemType SymbolicLink -Path "$claude\statusline.sh" -Target "$repo\config\statusline.sh"
Get-ChildItem "$repo\config\hooks\*.sh" | ForEach-Object {
  New-Item -ItemType SymbolicLink -Path "$claude\hooks\$($_.Name)" -Target $_.FullName
}
Get-ChildItem "$repo\skills" -Directory | ForEach-Object {
  New-Item -ItemType SymbolicLink -Path "$claude\skills\$($_.Name)" -Target $_.FullName
}
```

Expect: PowerShell lists each link it creates. An error about administrator
privilege means neither Developer Mode nor an elevated shell is in place (see
above).

Copy the files that are copied rather than linked, and wire the global gitignore:

```powershell
Copy-Item "$repo\config\settings.template.json" "$claude\settings.json"
Copy-Item "$repo\config\gitignore_global" "$env:USERPROFILE\.gitignore_global"
git config --global core.excludesfile "$env:USERPROFILE\.gitignore_global"
Copy-Item "$repo\config\npmrc" "$env:USERPROFILE\.npmrc"
```

Expect: nothing is printed.

Then edit `%USERPROFILE%\.claude\settings.json` by hand. `install.sh` normally
substitutes these; nothing else in the file is machine-specific.

| key | shipped value | what to put |
|---|---|---|
| `env.SSL_CERT_FILE`, `env.CARGO_HTTP_CAINFO` | `/etc/ssl/cert.pem` | your CA bundle, or delete both keys and let the tools use the system store |
| `env.EDITOR`, `env.VISUAL` | `nano` | `notepad`, which blocks until the window closes, or `code --wait`. Git for Windows does ship `nano.exe`, but under `usr\bin`, which only its third PATH option adds — and it is an MSYS binary, which this route otherwise avoids |
| `env.CLAUDE_KIT_COMMIT` | `auto` | `ask` to confirm every commit |
| `env.CLAUDE_KIT_PUSH` | `ask` | `never`, or `auto` to push and open PRs unprompted (main, force and `gh pr merge` still ask) |
| `sandbox.filesystem.allowWrite` | generated from the code roots `install.sh` asks about | wherever you keep repos — pass `--code-root` to skip the question |
| the five `~/Documents/claude-shared` paths | | where handoff docs should live, if not that |

Finally create the handoff directory and point the kit at it:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\Documents\claude-shared" | Out-Null
@{ default = "$env:USERPROFILE\Documents\claude-shared"; overrides = @{} } |
  ConvertTo-Json | Set-Content "$claude\shared-dirs.json"
```

Expect: nothing is printed. `Get-Content "$claude\shared-dirs.json"` shows the path
you just set.

Restart Claude Code, then check the parts most likely to be wrong:

- **Do the hooks run?** Try `git commit` on `main` in some repo. `git-workflow.sh`
  should ask you to branch first. Silence means `bash` is not resolving, and none
  of the guardrails are active.
- **Does `~` expand?** The permission and sandbox rules use `~/…`. If they are not
  expanded on Windows, replace them with absolute paths.
- **Is there a sandbox at all?** If `sandbox.enabled` has no effect, the
  filesystem and network limits are not protecting anything, and
  `autoAllowBashIfSandboxed` is granting commands on the strength of a sandbox
  that is not there. Turn that key off if so.
