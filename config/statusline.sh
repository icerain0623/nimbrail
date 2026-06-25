#!/usr/bin/env bash

# Line 1: model  ctx 34%  branch*
# Line 2: proj:~/path  [↳cwd]  5h 12%→06:20  7d 78%→13:53

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.cwd // "."')
branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)

# git dirty? (any staged/unstaged/untracked change)
dirty=""
if [ -n "$branch" ]; then
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    dirty="*"
  fi
fi

# Workspace dirs — fall back to cwd and git toplevel
ws_current=$(echo "$input" | jq -r '.workspace.current_dir // empty')
ws_project=$(echo "$input" | jq -r '.workspace.project_dir // empty')
[ -z "$ws_current" ] && ws_current="$cwd"
[ -z "$ws_project" ] && ws_project=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)

# ── Colors ────────────────────────────────────────────────────────────────────
RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
CYAN=$'\033[36m'
MAGENTA=$'\033[35m'
BLUE=$'\033[34m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'

# color by usage threshold: <50 green, <80 yellow, else red
usage_color() {
  local pct
  pct=$(printf '%.0f' "${1:-0}")
  if   [ "$pct" -lt 50 ]; then printf '%s' "$GREEN"
  elif [ "$pct" -lt 80 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$RED"
  fi
}

# Abbreviate $HOME to ~
home_escaped=$(printf '%s' "$HOME" | sed 's/[[\.*^$()+?{|]/\\&/g')
abbrev() {
  printf '%s' "$1" | sed "s|^${home_escaped}|~|"
}

# meter: "label NN%" with the percentage colored by threshold (no bar)
meter() {
  local label="$1" pct="$2"
  local c p
  c=$(usage_color "$pct")
  p=$(printf '%.0f' "$pct")
  printf '%s%s %s%s%%%s' "$DIM" "$label" "$c" "$p" "$RESET"
}

# ── Rate limits ────────────────────────────────────────────────────────────────
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

fmt_reset() {
  local ts="$1"
  if [ -n "$ts" ]; then
    date -r "$ts" '+%H:%M' 2>/dev/null || date -d "@$ts" '+%H:%M' 2>/dev/null
  fi
}

SEP="${DIM}  ${RESET}"  # two-space separator (subtle)

# ── Line 1: model  ctx  branch ─────────────────────────────────────────────────
if [ -n "$used" ]; then
  ctx_part=$(meter "ctx" "$used")
else
  ctx_part="${DIM}ctx -%${RESET}"
fi

line1="${BOLD}${CYAN}${model}${RESET}${SEP}${ctx_part}"
if [ -n "$branch" ]; then
  branch_part="${MAGENTA}${branch}${RESET}"
  [ -n "$dirty" ] && branch_part="${branch_part}${YELLOW}${dirty}${RESET}"
  line1="${line1}${SEP}${branch_part}"
fi
printf '%s' "$line1"

# ── Line 2: proj [↳cwd]  5h  7d ───────────────────────────────────────────────
parts=()
if [ -n "$ws_project" ]; then
  parts+=("${DIM}${BLUE}$(abbrev "$ws_project")${RESET}")
  # show cwd only when it differs from project root
  if [ -n "$ws_current" ] && [ "$ws_current" != "$ws_project" ]; then
    parts+=("${DIM}↳$(abbrev "$ws_current")${RESET}")
  fi
elif [ -n "$ws_current" ]; then
  parts+=("${DIM}${BLUE}$(abbrev "$ws_current")${RESET}")
fi

if [ -n "$five_pct" ]; then
  s=$(meter "5h" "$five_pct")
  r=$(fmt_reset "$five_resets")
  [ -n "$r" ] && s="${s}${DIM}→${r}${RESET}"
  parts+=("$s")
fi
if [ -n "$seven_pct" ]; then
  s=$(meter "7d" "$seven_pct")
  r=$(fmt_reset "$seven_resets")
  [ -n "$r" ] && s="${s}${DIM}→${r}${RESET}"
  parts+=("$s")
fi

if [ ${#parts[@]} -gt 0 ]; then
  line2=""
  for i in "${!parts[@]}"; do
    [ "$i" -gt 0 ] && line2="${line2}${SEP}"
    line2="${line2}${parts[$i]}"
  done
  printf '\n%s' "$line2"
fi
