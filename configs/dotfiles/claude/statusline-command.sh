#!/bin/bash
# Claude Code statusline. Reads statusline JSON on stdin, prints one line.
#
# Segments, left to right:
#   dir · branch │ model effort │ context │ turns │ prompt cache │ rate limits or cost
#
# Runs under bash 3.2 (macOS) and bash 5 (Linux); avoid 4+-only features.

input=$(cat)

# Thresholds at which a segment turns yellow, then red (percent; dollars for cost).
CTX_WARN=40  CTX_HOT=75
RL_WARN=60   RL_HOT=85
COST_WARN=5  COST_HOT=20

# One jq call extracts every field and type-checks it at the boundary, so the
# rest of the script can use the values in arithmetic and printf without
# quoting concerns: strings lose embedded newlines, anything that is not the
# expected type becomes "". Output is newline-separated (not @tsv) because bash
# IFS collapses empty tab fields. The read order must match the jq order.
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
  def str: if type == "string" then gsub("[\n\r]"; " ") else "" end;
  def num: if type == "number" then . else "" end;
  (.workspace.current_dir | str),
  (.context_window.used_percentage | num),
  (.context_window.total_input_tokens | num),
  (.context_window.total_output_tokens | num),
  (.transcript_path | str),
  (.rate_limits.five_hour.used_percentage | num),
  (.rate_limits.five_hour.resets_at | num),
  (.rate_limits.seven_day.used_percentage | num),
  (.rate_limits.seven_day.resets_at | num),
  (.cost.total_cost_usd | num),
  (.model.display_name | str),
  (.effort.level | str),
  (.prompt_cache.warm | if type == "boolean" then tostring else "" end),
  (.prompt_cache.expires_at | num),
  (.prompt_cache.ttl | if type == "string" and test("^[0-9]+[hm]$") then . else "" end)' <<<"$input")

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

# pct_color VALUE WARN HOT → color escape for VALUE against the two thresholds.
pct_color() {
  local p=${1%.*}
  if   [ "$p" -ge "$3" ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$p" -ge "$2" ] 2>/dev/null; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

# progress_bar PCT → seven-cell bar, PCT already an integer.
progress_bar() {
  local filled=$(( ($1 * 7 + 50) / 100 )) bar="" i
  [ "$filled" -gt 7 ] && filled=7
  for ((i=0; i<filled; i++));     do bar+="▓"; done
  for ((i=filled; i<7; i++));     do bar+="░"; done
  printf '%s' "$bar"
}

# short_dir PATH → last two path components.
short_dir() {
  case "$1" in
    /*/*) local parent=${1%/*}; printf '%s/%s' "${parent##*/}" "${1##*/}" ;;
    *)    printf '%s' "$1" ;;
  esac
}

# fmt_remaining EPOCH → "now" | "<1m" | "12m" | "3h".
fmt_remaining() {
  local diff=$(( ${1%.*} - now ))
  if   [ "$diff" -le 0 ];    then printf "now"
  elif [ "$diff" -ge 3600 ]; then printf "%dh" $(( (diff + 1800) / 3600 ))
  elif [ "$diff" -ge 60 ];   then printf "%dm" $(( (diff + 30) / 60 ))
  else                            printf "<1m"
  fi
}

# fmt_day EPOCH → "mon".."sun". BSD and GNU date take the epoch differently.
fmt_day() {
  case "$OSTYPE" in
    darwin*) date -r "${1%.*}" "+%a" 2>/dev/null ;;
    *)       date -d "@${1%.*}" "+%a" 2>/dev/null ;;
  esac | tr '[:upper:]' '[:lower:]'
}

# rl_seg LABEL PCT RESET FMT → "5h 33%→2h". FMT is the function that renders RESET.
rl_seg() {
  local label=$1 pct=$2 reset=$3 fmt=$4 p seg
  p=$(printf '%.0f' "$pct")
  seg="${GREY}${label}${RESET} $(pct_color "$p" "$RL_WARN" "$RL_HOT")${p}%${RESET}"
  [ -n "$reset" ] && seg+="${DIM}→$($fmt "$reset")${RESET}"
  printf '%s' "$seg"
}

# ctx_seg USED_PCT TOTAL_IN TOTAL_OUT → "▓▓▓░░░░ 42% (13.0k)".
ctx_seg() {
  local p seg combined tenths
  p=$(printf '%.0f' "$1")
  seg="$(pct_color "$p" "$CTX_WARN" "$CTX_HOT")$(progress_bar "$p") ${p}%${RESET}"
  if [ -n "$2" ] && [ -n "$3" ]; then
    combined=$(( ${2%.*} + ${3%.*} ))
    if [ "$combined" -ge 1000 ]; then
      tenths=$(( (combined + 50) / 100 ))
      seg+=" ${GREY}($(( tenths / 10 )).$(( tenths % 10 ))k)${RESET}"
    else
      seg+=" ${GREY}(${combined})${RESET}"
    fi
  fi
  printf '%s' "$seg"
}

# turn_count TRANSCRIPT → number of user-authored prompts, or "" for none.
# The transcript's user entries also include tool_result echoes (content is an
# array) and isMeta caveats; both are filtered out. grep narrows the file to
# candidate lines before jq parses them, so this stays around 50 ms even on
# multi-megabyte transcripts. The grep assumes compact JSON, which is how
# Claude Code writes the file.
turn_count() {
  local n
  [ -f "$1" ] || return
  n=$(grep '"type":"user"' "$1" | grep '"content":"' | jq -n '
    [inputs | select(.type=="user"
                     and (.isSidechain//false|not)
                     and (.isMeta//false|not)
                     and (.message.content|type)=="string")] | length' 2>/dev/null)
  [ -n "$n" ] && [ "$n" != "0" ] && printf '%s' "$n"
}

# cache_seg WARM EXPIRES_AT TTL → "● 30m" while warm, "○" once cold.
# EXPIRES_AT is epoch seconds, TTL is "5m" or "1h". The countdown only advances
# when the script re-runs, so settings.json should set statusLine.refreshInterval.
cache_seg() {
  local warm=$1 expires=${2%.*} ttl=300 remaining glyph
  case "$3" in
    *h) ttl=$(( ${3%h} * 3600 )) ;;
    *m) ttl=$(( ${3%m} * 60 )) ;;
  esac
  if [ "$warm" = "true" ] && [ -n "$expires" ]; then
    remaining=$(( expires - now ))
    [ "$remaining" -gt "$ttl" ] && remaining=$ttl
  else
    remaining=0
  fi
  if [ "$remaining" -le 0 ]; then
    printf '%s' "${DIM}○${RESET}"
    return
  fi
  if [ "$remaining" -le $(( ttl / 2 )) ]; then glyph="${YELLOW}●${RESET}"
  else                                          glyph="${GREEN}●${RESET}"
  fi
  if [ "$remaining" -ge 60 ]; then printf '%s' "${glyph} ${DIM}$(( remaining / 60 ))m${RESET}"
  else                             printf '%s' "${glyph} ${DIM}${remaining}s${RESET}"
  fi
}

# add SEPARATOR SEGMENT → append SEGMENT to the status line, after SEPARATOR
# unless it is the first segment.
status=""
add() {
  status+="${status:+ $1 }$2"
}

if [ -n "$cwd" ]; then
  add "" "${CYAN}$(short_dir "$cwd")${RESET}"
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  [ -n "$branch" ] && add "$DOT" "${GREEN}⎇ ${branch}${RESET}"
fi

[ -n "$model" ] && add "$SEP" "${BLUE}✦ ${model}${RESET}${effort:+ ${GREY}${effort}${RESET}}"

[ -n "$used_pct" ] && add "$SEP" "$(ctx_seg "$used_pct" "$total_in" "$total_out")"

turns=$(turn_count "$transcript")
[ -n "$turns" ] && add "$SEP" "${PURPLE}↻ ${turns}${RESET}"

[ -n "$pc_warm" ] && add "$SEP" "$(cache_seg "$pc_warm" "$pc_expires" "$pc_ttl")"

# Claude.ai subscriber rate limits; fall back to session cost on API billing.
if [ -n "$five_hour_pct" ] || [ -n "$seven_day_pct" ]; then
  rl=""
  [ -n "$five_hour_pct" ] && rl=$(rl_seg "5h" "$five_hour_pct" "$five_hour_reset" fmt_remaining)
  if [ -n "$seven_day_pct" ]; then
    s=$(rl_seg "7d" "$seven_day_pct" "$seven_day_reset" fmt_day)
    rl="${rl:+$rl ${DOT} }$s"
  fi
  add "$SEP" "$rl"
elif [ -n "$cost_usd" ]; then
  add "$SEP" "$(pct_color "$cost_usd" "$COST_WARN" "$COST_HOT")\$$(printf '%.2f' "$cost_usd")${RESET}"
fi

printf '%s' "$status"
