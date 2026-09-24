#!/bin/bash
# Package safety check hook
# Layer 1: Cache → Layer 2: Trusted scope → Layer 3: npm view → Layer 4: Socket.dev (minor packages only)

warn() {
  cat <<JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$1"}}
JSON
  exit 0
}

block() {
  cat <<JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$1"}}
JSON
  exit 0
}

# Read hook input from stdin
HOOK_INPUT=$(cat)
cmd=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command')

# Only process direct npm/pnpm/yarn commands, not embedded in scripts (node -e, python -c, etc.)
echo "$cmd" | grep -qE '(node|python|ruby|perl)[[:space:]]+-[ec]' && exit 0

# Take the first shell segment that STARTS with an install command (after env
# assignments or `mise exec --`). Matching anywhere let a commit message or
# heredoc that merely mentions `pnpm add` feed its prose to npm view.
# shellcheck disable=SC2020  # mapping each separator to a newline is the intent
install_part=$(printf '%s\n' "$cmd" | tr ';|&' '\n\n\n' \
  | sed -E 's/[[:space:]]*[0-9]*>.*//' \
  | grep -m1 -E '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(mise exec --[[:space:]]+)?(npm (install|i|add)|pnpm add|yarn add)([[:space:]]|$)')
[ -z "$install_part" ] && exit 0

# Skip: no-arg installs (npm install, npm ci, etc.)
echo "$install_part" | grep -qE '(npm (install|i|ci)|pnpm install|yarn install?)[[:space:]]*$' && exit 0

# Extract package names (strip flags like -D, --save-dev, etc.)
# Keep only tokens shaped like a package spec: an unexpanded `$VAR` or a quoted
# fragment cannot be looked up, and asking npm about it only yields a false alarm.
pkgs=$(echo "$install_part" | sed -nE 's/.*(npm (install|i|add)|pnpm add|yarn add)[[:space:]]+//p' | tr ' ' '\n' | grep -vE '^-' \
  | grep -E '^(@[A-Za-z0-9._~-]+/)?[A-Za-z0-9._~-]+(@[A-Za-z0-9._~^<>=|*+-]*)?$' | head -5)
[ -z "$pkgs" ] && exit 0

# Known trusted scopes
trusted_scopes="^@(types|next|react|babel|eslint|typescript-eslint|tailwindcss|prisma|tanstack|trpc|t3-oss|vercel|supabase|clerk|auth|sentry|radix-ui|shadcn|testing-library|storybook|vitejs|vitest|swc|emotion|mui|chakra-ui|mantine|headlessui|floating-ui|dnd-kit|reduxjs|anthropic-ai)/"

# Cache dir (24h TTL)
cache_dir="${TMPDIR:-/tmp}/socket-cache"
mkdir -p "$cache_dir" 2>/dev/null

DL_THRESHOLD_SKIP_SOCKET=10000
DL_THRESHOLD_WARN=500
STALE_DAYS=730

warnings=""

for pkg in $pkgs; do
  # --- Layer 2: Trusted scope ---
  echo "$pkg" | grep -qE "$trusted_scopes" && continue

  # Strip version specifier for cache key (e.g., react@18 -> react)
  pkg_key=$(echo "$pkg" | sed 's/@[^/]*$//')

  # --- Layer 1: Cache (24h TTL) ---
  # Flatten scoped names (@scope/pkg) so the cache file is a single flat path —
  # otherwise the write fails because the @scope subdir does not exist.
  cache_file="$cache_dir/$(echo "$pkg_key" | tr '/@' '__')"
  if [ -f "$cache_file" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null) ))
    if [ "$age" -lt 86400 ]; then
      cached_status=$(cat "$cache_file")
      [ "$cached_status" = "ok" ] && continue
      warnings="$warnings$cached_status\n"
      continue
    fi
  fi

  # --- Layer 3: npm view (free, no quota) ---
  info=$(npm view "$pkg" --json 2>/dev/null)
  # `npm view <missing> --json` returns an {"error":...} object on stdout (not an
  # empty string), so the bare -z test never fired — check both.
  if [ -z "$info" ] || echo "$info" | jq -e '.error' >/dev/null 2>&1; then
    warn "Package '$pkg' not found on npm registry"
  fi

  # 3a. Deprecated check → block
  dep=$(echo "$info" | jq -r '.deprecated // empty')
  if [ -n "$dep" ]; then
    echo "BLOCKED: $pkg deprecated — $dep" > "$cache_file"
    block "DEPRECATED: $pkg — $dep"
  fi

  # 3b. Weekly downloads
  dl_url="https://api.npmjs.org/downloads/point/last-week/$pkg_key"
  downloads=$(curl -sf --connect-timeout 3 --max-time 8 "$dl_url" | jq -r '.downloads // 0' 2>/dev/null)
  downloads=${downloads:-0}

  # 3c. Last modified date
  mod=$(echo "$info" | jq -r '.time.modified // empty' 2>/dev/null)
  days_old=0
  if [ -n "$mod" ]; then
    mod_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${mod%%.*}" +%s 2>/dev/null)
    if [ -n "$mod_epoch" ]; then
      days_old=$(( ($(date +%s) - mod_epoch) / 86400 ))
    fi
  fi

  # 3d. Low downloads → warn (no socket needed)
  if [ "$downloads" -lt "$DL_THRESHOLD_WARN" ] 2>/dev/null; then
    msg="WARNING: '$pkg' low popularity ($downloads downloads/week)"
    echo "$msg" > "$cache_file"
    warnings="$warnings$msg\n"
    continue
  fi

  # 3e. Stale package → warn (no socket needed)
  if [ "$days_old" -gt "$STALE_DAYS" ] 2>/dev/null; then
    msg="WARNING: '$pkg' last updated $days_old days ago"
    echo "$msg" > "$cache_file"
    warnings="$warnings$msg\n"
    continue
  fi

  # 3f. Popular package (>10k DL/week) → trust, skip socket
  if [ "$downloads" -gt "$DL_THRESHOLD_SKIP_SOCKET" ] 2>/dev/null; then
    echo "ok" > "$cache_file"
    continue
  fi

  # --- Layer 4: Socket.dev (only for 500-10k DL range) ---
  if ! command -v socket &>/dev/null; then
    echo "ok" > "$cache_file"
    continue
  fi

  result=$(socket package score npm "$pkg" --json 2>&1)
  exit_code=$?

  # Quota exceeded → ask user
  if echo "$result" | grep -qiE '(rate.?limit|quota|429|too many requests)'; then
    warn "Socket.dev quota exceeded — cannot verify '$pkg'. Proceed?"
  fi

  # API failure → pass through (npm view already checked)
  if [ $exit_code -ne 0 ] || [ "$(echo "$result" | jq -r '.ok // empty' 2>/dev/null)" != "true" ]; then
    echo "ok" > "$cache_file"
    continue
  fi

  # Parse scores
  overall=$(echo "$result" | jq -r '.data.self.score.overall // 0')
  vuln=$(echo "$result" | jq -r '.data.self.score.vulnerability // 0')
  supply=$(echo "$result" | jq -r '.data.self.score.supplyChain // 0')
  has_critical=$(echo "$result" | jq -r '.data.self.alerts[]? | select(.severity == "high" or .severity == "critical") | .name' | head -1)

  # Decision
  if [ "$vuln" -lt 50 ] 2>/dev/null; then
    msg="BLOCKED: '$pkg' vulnerability score $vuln/100"
    echo "$msg" > "$cache_file"
    block "$msg"
  elif [ "$overall" -lt 50 ] 2>/dev/null; then
    msg="BLOCKED: '$pkg' overall score $overall/100"
    echo "$msg" > "$cache_file"
    block "$msg"
  elif [ "$overall" -lt 70 ] 2>/dev/null; then
    msg="WARNING: '$pkg' overall=$overall vuln=$vuln supply=$supply"
    echo "$msg" > "$cache_file"
    warnings="$warnings$msg\n"
  elif [ -n "$has_critical" ]; then
    msg="WARNING: '$pkg' has critical alert: $has_critical (overall=$overall)"
    echo "$msg" > "$cache_file"
    warnings="$warnings$msg\n"
  else
    echo "ok" > "$cache_file"
  fi
done

# Show accumulated warnings
if [ -n "$warnings" ]; then
  warn "$(echo -e "$warnings" | tr '\n' ' ')"
fi
