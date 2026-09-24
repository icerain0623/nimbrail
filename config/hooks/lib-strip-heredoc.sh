#!/bin/bash
# Filter, not a hook: read a Bash command on stdin, print it with heredoc bodies
# removed. The command-matching hooks run their checks on this output, so text
# that is only data — a `git commit -F -` message, a `python3 - <<EOF` script, a
# file written with `cat > f <<EOF` — stops being read as commands. That class of
# false positive hit block-dev-servers and the claude-shared guard alike.
#
# A heredoc fed to a shell (`bash <<EOF`, `sh -s <<EOF`, `zsh <<EOF`) IS commands,
# so its body is kept: dropping it would let the deny guards miss a real `rm`.
# `<<<` here-strings are left alone; they carry no body lines.
#
# Unterminated heredoc → the rest is dropped, which matches what the shell does.

awk '
  inh {
    line = $0
    if (strip_tabs) sub(/^\t+/, "", line)
    if (line == tag) inh = 0
    else if (keep) print
    next
  }
  {
    print
    probe = $0
    gsub(/<<</, "\001\001\001", probe)        # hide here-strings from the match
    if (match(probe, /<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
      op = substr(probe, RSTART, RLENGTH)
      strip_tabs = (op ~ /^<<-/)
      t = op; sub(/^<<-?[ \t]*/, "", t); gsub(/["\047]/, "", t)
      tag = t; inh = 1
      before = substr(probe, 1, RSTART - 1)
      keep = (before ~ /(^|[;&|( \t])(bash|sh|zsh|dash|ksh)([ \t]+-[A-Za-z]+)*[ \t]*$/)
    }
  }
'
