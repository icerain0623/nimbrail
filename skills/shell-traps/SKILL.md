---
name: shell-traps
description: Silent zsh/BSD shell traps — word splitting, glob aborts, missing GNU flags, aliased `ls`, the ASI break in pasted one-liners. Use when a command returns nothing, a sweep reports clean without running, or before handing someone a command to paste.
---

# shell-traps

Every trap here is silent: the command exits 0, or the error is swallowed, and the
run reports success on zero work. That is why they belong in a list rather than in
whichever skill happened to hit one.

## zsh

- **Unquoted expansion does not word-split.** `grep $FILES` passes the whole list as
  one argument, matching nothing, and `git grep <pat> $ALL` passed 160 shas as a
  single path and died on `failed to stat` — hidden by `2>/dev/null`, which then
  reported "clean". Write `${=VAR}` to split explicitly, or use an array.
- **`no matches found` aborts the whole command.** An unmatched glob is a zsh error,
  not an empty expansion as in bash, so the command never runs. Quote the pattern
  when the callee expands it, or `setopt null_glob` for that line.

## BSD / macOS

- `xargs -a` does not exist. Redirect instead: `xargs … < file`.
- **`ls` is often aliased to `eza`**, where `-t` means `--time FIELD` rather than
  sort-by-time, so `ls -t <files>` eats the first filename as the field name and
  fails. Call `command ls`, or use `find`/`stat` when the output is being parsed.

## Handing a one-liner to a human

A multi-line function declaration survives being pasted; a one-liner does not. Wrapped
in a terminal or a chat client, ASI turns `return` at a line break into `return;` and
the rest of the expression is silently dropped. Write it as a multi-line declaration,
or put it in a file under the scratchpad and have them copy from there.

## Rules

- Never let `2>/dev/null` or `| head` cover a command whose failure would change the
  conclusion — that is what turns a trap into a false "clean".
- A sweep that reports zero findings states what it actually ran over (file count,
  range), so an empty result is distinguishable from an unrun one.
