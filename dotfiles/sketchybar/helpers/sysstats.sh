#!/usr/bin/env bash
# Emit a single compact, monochrome line for the SketchyBar sysstats widget:
#   CPU 23%  RAM 39%  ↓1.2M ↑0.3M
# Pure shell (no compiled provider) so it survives a fresh-Mac setup without a
# C toolchain build step. Network rate is derived from byte counters sampled
# between calls, persisted in a state file in $TMPDIR.
set -uo pipefail

IFACE="${1:-en0}"
STATE="${TMPDIR:-/tmp}/sketchybar_sysstats_net"

# --- CPU: take the 2nd sample of `top` (the 1st is a useless cumulative one) ---
cpu=$(top -l 2 -n 0 2>/dev/null \
  | awk '/CPU usage/ { u=$3; s=$5 } END { gsub(/%/,"",u); gsub(/%/,"",s); printf "%.0f", u+s }')
[ -z "$cpu" ] && cpu=0

# --- RAM: used % = (active + wired + compressed) / total, like Activity Monitor.
# memory_pressure's "free percentage" only counts truly-free pages and wildly
# under-reports what the user sees as used, so derive it from vm_stat instead. ---
ram=$(vm_stat 2>/dev/null | awk '
  /Pages free/                   { f=$3 }
  /Pages active/                 { a=$3 }
  /Pages inactive/               { i=$3 }
  /Pages speculative/            { sp=$3 }
  /Pages wired/                  { w=$4 }
  /Pages occupied by compressor/ { c=$5 }
  END {
    gsub(/\./,"",f); gsub(/\./,"",a); gsub(/\./,"",i)
    gsub(/\./,"",sp); gsub(/\./,"",w); gsub(/\./,"",c)
    total=f+a+i+sp+w+c
    if (total > 0) printf "%.0f", (a+w+c)*100/total; else printf "0"
  }')
[ -z "$ram" ] && ram=0

# --- Network: bytes-in / bytes-out for IFACE, rate via delta over elapsed time ---
read -r ib ob < <(netstat -ibI "$IFACE" 2>/dev/null \
  | awk 'NR>1 && $1=="'"$IFACE"'" { print $7, $10; exit }')
ib=${ib:-0}; ob=${ob:-0}
now=$(date +%s)

down_rate=0; up_rate=0
if [ -r "$STATE" ]; then
  read -r p_now p_ib p_ob < "$STATE" 2>/dev/null || true
  elapsed=$(( now - ${p_now:-now} ))
  if [ "${elapsed:-0}" -gt 0 ] && [ -n "${p_ib:-}" ]; then
    # Counters can reset (interface down / overflow); clamp negatives to 0.
    d=$(( ib - p_ib )); [ "$d" -lt 0 ] && d=0
    u=$(( ob - p_ob )); [ "$u" -lt 0 ] && u=0
    down_rate=$(( d / elapsed ))
    up_rate=$(( u / elapsed ))
  fi
fi
printf '%s %s %s\n' "$now" "$ib" "$ob" > "$STATE"

fmt() { # bytes/s -> compact human string
  local b=$1
  if   [ "$b" -lt 1024 ];    then printf '%dB' "$b"
  elif [ "$b" -lt 1048576 ]; then printf '%dK' "$(( b / 1024 ))"
  else awk "BEGIN { printf \"%.1fM\", $b/1048576 }"
  fi
}

printf 'CPU %s%%  RAM %s%%  ↓%s ↑%s\n' "$cpu" "$ram" "$(fmt "$down_rate")" "$(fmt "$up_rate")"
