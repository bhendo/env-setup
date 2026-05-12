#!/bin/bash
# Claude Code Status Line
# Mirrors terminal prompt with git branch, directory, context info, token usage, and turn count

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ANSI colors (256-color where useful). Suppressed if NO_COLOR is set.
if [ -z "$NO_COLOR" ]; then
  RESET=$'\033[0m'
  DIM=$'\033[2m'
  BOLD=$'\033[1m'
  CYAN=$'\033[38;5;38m'
  GREEN=$'\033[38;5;42m'
  YELLOW=$'\033[38;5;214m'
  RED=$'\033[38;5;203m'
  PURPLE=$'\033[38;5;141m'
  GREY=$'\033[38;5;245m'
else
  RESET="" DIM="" BOLD="" CYAN="" GREEN="" YELLOW="" RED="" PURPLE="" GREY=""
fi

SEP="${DIM}│${RESET}"
DOT="${DIM}·${RESET}"

# Pick a color based on a percentage. Optional args: yellow-threshold, red-threshold.
# Defaults: yellow >=60, red >=85.
pct_color() {
  local p=${1%.*}
  local y=${2:-60}
  local r=${3:-85}
  if   [ "$p" -ge "$r" ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$p" -ge "$y" ] 2>/dev/null; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

# Render a 7-cell progress bar for a percentage 0..100 using ░▓.
progress_bar() {
  local p=${1%.*}
  [ -z "$p" ] && p=0
  local filled=$(( (p * 7 + 50) / 100 ))
  [ "$filled" -gt 7 ] && filled=7
  [ "$filled" -lt 0 ] && filled=0
  local empty=$(( 7 - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="▓"; done
  for ((i=0; i<empty;  i++)); do bar+="░"; done
  printf '%s' "$bar"
}

# Get git branch (skip optional locks for safety)
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" -c core.fileMode=false branch --show-current 2>/dev/null || echo "")
fi

# Format directory (show last 2 components for brevity)
short_dir=$(echo "$cwd" | awk -F'/' '{
  if (NF <= 2) print $0
  else print $(NF-1)"/"$NF
}')

# Count turns from transcript. A "turn" = one user-authored prompt.
# Transcript user entries also include tool_result echoes (content is an array)
# and meta caveats (isMeta=true); exclude both. Keep slash commands.
turn_count=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  turns=$(jq -c 'select(.type=="user"
              and (.isSidechain // false | not)
              and (.isMeta // false | not)
              and (.message.content | type) == "string")' \
          "$transcript" 2>/dev/null | wc -l | tr -d ' ')
  if [ -n "$turns" ] && [ "$turns" -gt 0 ] 2>/dev/null; then
    turn_count="$turns"
  fi
fi

# Build status line
status=""

# Directory (cyan)
status+="${CYAN}${short_dir}${RESET}"

# Git branch (green, with a small glyph)
if [ -n "$git_branch" ]; then
  status+=" ${DOT} ${GREEN}⎇ ${git_branch}${RESET}"
fi

# Context usage: bar + percentage + raw tokens, color-coded by threshold
if [ -n "$used_pct" ]; then
  pct_int=$(printf '%.0f' "$used_pct")
  c=$(pct_color "$pct_int" 40 75)
  bar=$(progress_bar "$pct_int")
  ctx_seg="${c}${bar} ${pct_int}%${RESET}"
  if [ -n "$total_in" ] && [ -n "$total_out" ]; then
    combined=$((total_in + total_out))
    if [ "$combined" -ge 1000 ] 2>/dev/null; then
      total_tokens=$(awk "BEGIN {printf \"%.1fk\", $combined/1000}")
    else
      total_tokens="$combined"
    fi
    ctx_seg+=" ${GREY}(${total_tokens})${RESET}"
  fi
  status+=" ${SEP} ${ctx_seg}"
fi

# Turn count (purple)
if [ -n "$turn_count" ]; then
  status+=" ${SEP} ${PURPLE}↻ ${turn_count}${RESET}"
fi

# Prompt-cache window: Anthropic's prompt cache has a 5-minute TTL refreshed by
# every cache-eligible request. Show the absolute local-clock expiry so you can
# compare it to your own clock — the statusline doesn't tick on its own.
cache_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  last_ts=$(jq -r 'select(.type=="assistant" and (.isSidechain // false | not)) | .timestamp' "$transcript" 2>/dev/null | tail -1)
  if [ -n "$last_ts" ] && [ "$last_ts" != "null" ]; then
    base=${last_ts%.*}; base=${base%Z}
    last_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$base" +%s 2>/dev/null)
    if [ -n "$last_epoch" ]; then
      remaining=$((last_epoch + 300 - $(date +%s)))
      [ "$remaining" -gt 300 ] && remaining=300
      if [ "$remaining" -gt 0 ]; then
        m=$((remaining / 60)); s=$((remaining % 60))
        if [ "$remaining" -le 150 ]; then
          glyph="${YELLOW}●${RESET}"
        else
          glyph="${GREEN}●${RESET}"
        fi
        if [ "$m" -gt 0 ]; then
          cache_seg="${glyph} ${DIM}${m}m${s}s${RESET}"
        else
          cache_seg="${glyph} ${DIM}${s}s${RESET}"
        fi
      else
        cache_seg="${DIM}○${RESET}"
      fi
    fi
  fi
fi
[ -n "$cache_seg" ] && status+=" ${SEP} ${cache_seg}"

# Add Claude.ai rate limit usage (subscriber-only; absent otherwise).
# 5h suffix shows time-remaining ("2h13m"), 7d shows the weekday it resets on.
fmt_remaining() {
  local diff=$(( $1 - $(date +%s) ))
  if [ "$diff" -le 0 ]; then printf "now"; return; fi
  local h=$(( diff / 3600 )) m=$(( (diff % 3600) / 60 ))
  if [ "$h" -gt 0 ]; then printf "%dh%dm" "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf "%dm" "$m"
  else printf "<1m"; fi
}
fmt_day() { date -r "$1" "+%a" 2>/dev/null | tr '[:upper:]' '[:lower:]'; }

if [ -n "$five_hour_pct" ] || [ -n "$seven_day_pct" ]; then
  rl=""
  if [ -n "$five_hour_pct" ]; then
    p=$(printf '%.0f' "$five_hour_pct")
    c=$(pct_color "$p")
    seg="${GREY}5h${RESET} ${c}${p}%${RESET}"
    [ -n "$five_hour_reset" ] && seg+="${DIM}→$(fmt_remaining "$five_hour_reset")${RESET}"
    rl="$seg"
  fi
  if [ -n "$seven_day_pct" ]; then
    p=$(printf '%.0f' "$seven_day_pct")
    c=$(pct_color "$p")
    seg="${GREY}7d${RESET} ${c}${p}%${RESET}"
    [ -n "$seven_day_reset" ] && seg+="${DIM}→$(fmt_day "$seven_day_reset")${RESET}"
    rl="${rl:+$rl ${DIM}·${RESET} }$seg"
  fi
  status+=" ${SEP} ${rl}"
fi

# Print without trailing prompt character
printf "%s" "$status"
