#!/bin/bash
# Claude Code statusline. Reads statusline JSON on stdin, prints one line.

input=$(cat)

# Newline-separated (not @tsv) — bash IFS treats tab as whitespace and collapses
# empty fields, which silently misaligns columns when a value is null.
{
  read -r cwd
  read -r used_pct
  read -r total_in
  read -r total_out
  read -r transcript
  read -r five_hour_pct
  read -r five_hour_reset
  read -r seven_day_pct
  read -r seven_day_reset
  read -r cost_usd
  read -r model
  read -r effort
  read -r pc_warm
  read -r pc_expires
  read -r pc_ttl
} < <(jq -r '
  .workspace.current_dir // "",
  .context_window.used_percentage // "",
  .context_window.total_input_tokens // "",
  .context_window.total_output_tokens // "",
  .transcript_path // "",
  .rate_limits.five_hour.used_percentage // "",
  .rate_limits.five_hour.resets_at // "",
  .rate_limits.seven_day.used_percentage // "",
  .rate_limits.seven_day.resets_at // "",
  .cost.total_cost_usd // "",
  .model.display_name // "",
  .effort.level // "",
  (.prompt_cache.warm | if . == null then "" else tostring end),
  .prompt_cache.expires_at // "",
  .prompt_cache.ttl // ""' <<<"$input")

if [ -z "$NO_COLOR" ]; then
  RESET=$'\033[0m'
  DIM=$'\033[2m'
  CYAN=$'\033[38;5;38m'
  GREEN=$'\033[38;5;42m'
  YELLOW=$'\033[38;5;214m'
  RED=$'\033[38;5;203m'
  PURPLE=$'\033[38;5;141m'
  GREY=$'\033[38;5;245m'
  BLUE=$'\033[38;5;110m'
else
  RESET="" DIM="" CYAN="" GREEN="" YELLOW="" RED="" PURPLE="" GREY="" BLUE=""
fi

SEP="${DIM}│${RESET}"
DOT="${DIM}·${RESET}"
now=$(date +%s)

pct_color() {
  local p=${1%.*} y=${2:-60} r=${3:-85}
  if   [ "$p" -ge "$r" ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$p" -ge "$y" ] 2>/dev/null; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

progress_bar() {
  local p=${1%.*}
  [ -z "$p" ] && p=0
  local filled=$(( (p * 7 + 50) / 100 ))
  [ "$filled" -gt 7 ] && filled=7
  [ "$filled" -lt 0 ] && filled=0
  local empty=$(( 7 - filled )) bar="" i
  for ((i=0; i<filled; i++)); do bar+="▓"; done
  for ((i=0; i<empty;  i++)); do bar+="░"; done
  printf '%s' "$bar"
}

# BSD `date` only; matches the host platform (darwin).
iso_to_epoch() {
  local iso=${1%.*}; iso=${iso%Z}
  [ -z "$iso" ] && return
  date -j -u -f "%Y-%m-%dT%H:%M:%S" "$iso" +%s 2>/dev/null
}

fmt_remaining() {
  local diff=$(( $1 - now ))
  if   [ "$diff" -le 0 ];    then printf "now"
  elif [ "$diff" -ge 3600 ]; then printf "%dh" $(( (diff + 1800) / 3600 ))
  elif [ "$diff" -ge 60 ];   then printf "%dm" $(( (diff + 30) / 60 ))
  else                            printf "<1m"
  fi
}
fmt_day() { date -r "$1" "+%a" 2>/dev/null | tr '[:upper:]' '[:lower:]'; }

rl_seg() {
  local label=$1 pct=$2 reset=$3 fmt=$4 p c seg
  p=$(printf '%.0f' "$pct")
  c=$(pct_color "$p")
  seg="${GREY}${label}${RESET} ${c}${p}%${RESET}"
  [ -n "$reset" ] && seg+="${DIM}→$($fmt "$reset")${RESET}"
  printf '%s' "$seg"
}

git_branch=""
[ -n "$cwd" ] && git_branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

case "$cwd" in
  /*/*) short_dir="${cwd%/*}"; short_dir="${short_dir##*/}/${cwd##*/}" ;;
  *)    short_dir=$cwd ;;
esac

# Turn = one user-authored prompt. The transcript's user entries also include
# tool_result echoes (content is an array) and isMeta caveats; both filtered.
# grep narrows the file to candidate lines (a superset) before jq parses them,
# since this runs every refreshInterval and transcripts reach tens of MB.
turn_count=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  turn_count=$(grep '"type":"user"' "$transcript" | grep '"content":"' | jq -n '
    [inputs | select(.type=="user"
                     and (.isSidechain//false|not)
                     and (.isMeta//false|not)
                     and (.message.content|type)=="string")] | length' 2>/dev/null)
  [ "$turn_count" = "0" ] && turn_count=""
fi

status="${CYAN}${short_dir}${RESET}"

if [ -n "$git_branch" ]; then
  status+=" ${DOT} ${GREEN}⎇ ${git_branch}${RESET}"
fi

if [ -n "$model" ]; then
  status+=" ${SEP} ${BLUE}✦ ${model}${RESET}"
  [ -n "$effort" ] && status+=" ${GREY}${effort}${RESET}"
fi

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

if [ -n "$turn_count" ]; then
  status+=" ${SEP} ${PURPLE}↻ ${turn_count}${RESET}"
fi

# Prompt cache. Prefer the harness's own accounting (prompt_cache.expires_at is
# epoch seconds, ttl is "5m" or "1h"); older versions don't report it, so fall
# back to a 5-minute window from the last assistant timestamp. The countdown
# only advances when the script re-runs, so settings.json sets a
# statusLine.refreshInterval; minute granularity matches that cadence.
cache_expires=""; cache_ttl=300
if [ -n "$pc_warm" ]; then
  if [ "$pc_warm" = "true" ] && [ -n "$pc_expires" ]; then
    cache_expires=$pc_expires
    case "$pc_ttl" in
      *h) cache_ttl=$(( ${pc_ttl%h} * 3600 )) ;;
      *m) cache_ttl=$(( ${pc_ttl%m} * 60 )) ;;
    esac
  else
    cache_expires=0
  fi
elif [ -n "$transcript" ] && [ -f "$transcript" ]; then
  last_ts=$(grep '"type":"assistant"' "$transcript" | tail -1 | jq -r '.timestamp // ""' 2>/dev/null)
  last_epoch=$(iso_to_epoch "$last_ts")
  [ -n "$last_epoch" ] && cache_expires=$((last_epoch + 300))
fi

if [ -n "$cache_expires" ]; then
  remaining=$((cache_expires - now))
  [ "$remaining" -gt "$cache_ttl" ] && remaining=$cache_ttl
  if [ "$remaining" -gt 0 ]; then
    if [ "$remaining" -le $((cache_ttl / 2)) ]; then glyph="${YELLOW}●${RESET}"
    else                                            glyph="${GREEN}●${RESET}"
    fi
    if [ "$remaining" -ge 60 ]; then cache_seg="${glyph} ${DIM}$((remaining / 60))m${RESET}"
    else                             cache_seg="${glyph} ${DIM}${remaining}s${RESET}"
    fi
  else
    cache_seg="${DIM}○${RESET}"
  fi
  status+=" ${SEP} ${cache_seg}"
fi

# Claude.ai subscriber rate limits; fall back to session cost on API billing.
if [ -n "$five_hour_pct" ] || [ -n "$seven_day_pct" ]; then
  rl=""
  [ -n "$five_hour_pct" ] && rl=$(rl_seg "5h" "$five_hour_pct" "$five_hour_reset" fmt_remaining)
  if [ -n "$seven_day_pct" ]; then
    s=$(rl_seg "7d" "$seven_day_pct" "$seven_day_reset" fmt_day)
    rl="${rl:+$rl ${DOT} }$s"
  fi
  status+=" ${SEP} ${rl}"
elif [ -n "$cost_usd" ]; then
  cost_fmt=$(awk "BEGIN {printf \"%.2f\", $cost_usd}")
  c=$(pct_color "$cost_usd" 5 20)
  status+=" ${SEP} ${c}\$${cost_fmt}${RESET}"
fi

printf "%s" "$status"
