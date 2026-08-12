---
name: python-setup
description: Set up a sandbox-safe Python environment for a project. Use when `python` is missing, pip installs fail under the sandbox, or a project needs an isolated interpreter.
---

# Python Setup

macOS ships only `python3`; the system interpreter and its default pip cache (`~/Library/Caches/pip`) are outside the sandbox's writable paths, so installs there fail. Use a project-local venv.

## Reuse before creating
If the project already has an interpreter, use it instead of reinstalling:
- An existing `.venv/` or `venv/` in the repo → use `.venv/bin/python`.
- An IDE-configured interpreter (JetBrains/WebStorm/PyCharm: look in `.idea/`, or a `.venv` the IDE made) → use that path.
- A `.python-version` (pyenv) or `.tool-versions`/`.mise.toml` pin → honor it.

## Create a project venv (none of the above exists)
From the repo root:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/pip install -r requirements.txt   # if present
```

Then always invoke `.venv/bin/python` / `.venv/bin/pip`.

- Add `.venv/` to `.gitignore` if not already covered.
- If pip still writes `~/Library/Caches/pip`, set `PIP_CACHE_DIR="$PWD/.venv/.pip-cache"` or pass `--no-cache-dir`.

## Pinned version (pyenv)
`~/.pyenv` is sandbox-writable:

```bash
pyenv install 3.12.4   # if missing
pyenv local 3.12.4     # writes .python-version
python3 -m venv .venv  # then the venv flow above
```

## Notes
- If a tool needs to run unsandboxed (e.g. a host DB), have the user run it via `!` rather than weakening the sandbox.
