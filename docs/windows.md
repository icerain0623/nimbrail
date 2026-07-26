# Windows

`install.sh` is bash and it builds a tree of symlinks, so it is written for macOS
and Linux. This page covers the two ways to get the kit onto a Windows machine.

**None of this has been run on Windows.** The author has no Windows machine. The
WSL route is ordinary Linux and should just work; the native route is reasoned
from what the files do, not observed, and the parts that are genuinely unknown are
marked as such. Corrections are welcome as issues — see
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

```powershell
wsl --install          # skip if you already have a distro
```

Then, **inside** WSL:

```bash
sudo apt install jq git         # jq is required; the hooks parse their input with it
cd ~                            # NOT /mnt/c — see below
git clone https://github.com/<you>/claude-kit.git
cd claude-kit
./install.sh
```

Two things that bite here:

- **Clone inside the WSL filesystem** (`~/…`), not under `/mnt/c/…`. The Windows
  mount does not carry Unix permissions or symlinks properly, and `install.sh`
  builds a tree of symlinks. Running it under `/mnt/c` is the single most likely
  way to get a broken install.
- **Run Claude Code from inside WSL too.** A Windows-side Claude Code reads
  `C:\Users\you\.claude`, not the `~/.claude` you just populated. They are
  different homes; installing in one and running in the other looks like the
  install silently did nothing.

If you run `install.sh` from Git Bash, MSYS or Cygwin, it stops and prints this
same advice rather than half-installing.

## Native Windows (manual, untested)

Do by hand what `install.sh` does. Paths below assume `%USERPROFILE%` is your home
and `REPO` is your clone.

Symlinks need Developer Mode on, or an elevated shell. If neither is available,
copy instead of linking — everything still works, but edits in the repo no longer
reach `~/.claude` and you have to re-copy after every `git pull`.

```powershell
$claude = "$env:USERPROFILE\.claude"
$repo   = "C:\path\to\claude-kit"
New-Item -ItemType Directory -Force "$claude\hooks", "$claude\skills" | Out-Null

New-Item -ItemType SymbolicLink -Path "$claude\CLAUDE.md"     -Target "$repo\config\CLAUDE.md"
New-Item -ItemType SymbolicLink -Path "$claude\statusline.sh" -Target "$repo\config\statusline.sh"
Get-ChildItem "$repo\config\hooks\*.sh" | ForEach-Object {
  New-Item -ItemType SymbolicLink -Path "$claude\hooks\$($_.Name)" -Target $_.FullName
}
Get-ChildItem "$repo\skills" -Directory | ForEach-Object {
  New-Item -ItemType SymbolicLink -Path "$claude\skills\$($_.Name)" -Target $_.FullName
}

Copy-Item "$repo\config\settings.template.json" "$claude\settings.json"
Copy-Item "$repo\config\gitignore_global" "$env:USERPROFILE\.gitignore_global"
git config --global core.excludesfile "$env:USERPROFILE\.gitignore_global"
Copy-Item "$repo\config\npmrc" "$env:USERPROFILE\.npmrc"
```

Then edit `%USERPROFILE%\.claude\settings.json` by hand. `install.sh` normally
substitutes these; nothing else in the file is machine-specific.

| key | shipped value | what to put |
|---|---|---|
| `env.SSL_CERT_FILE`, `env.CARGO_HTTP_CAINFO` | `/etc/ssl/cert.pem` | your CA bundle, or delete both keys and let the tools use the system store |
| `env.EDITOR`, `env.VISUAL` | `webstorm --wait` | whatever you use, or `code --wait` |
| `env.CLAUDE_KIT_COMMIT` | `auto` | `ask` to confirm every commit |
| `env.CLAUDE_KIT_PUSH` | `ask` | `never`, or `auto` to push unprompted where a linter or CI exists |
| `sandbox.filesystem.allowWrite` | `~/Documents/GitHub`, `~/Developers` | wherever you keep repos |
| the five `~/Documents/claude-shared` paths | | where handoff docs should live, if not that |

Finally create the handoff directory and point the kit at it:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\Documents\claude-shared" | Out-Null
@{ default = "$env:USERPROFILE\Documents\claude-shared"; overrides = @{} } |
  ConvertTo-Json | Set-Content "$claude\shared-dirs.json"
```

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
