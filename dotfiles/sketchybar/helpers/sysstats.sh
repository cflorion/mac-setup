#!/usr/bin/env bash
# Emit a single compact, monochrome, fixed-width line for the SketchyBar
# sysstats widget:
#   CPU 23%  RAM 52%
# Percentages are zero-padded to 2 digits so the widget width never jitters
# (mono font). Pure shell (no compiled provider) so it survives a fresh-Mac
# setup without a C toolchain build step.
set -uo pipefail

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

printf 'CPU %02d%%  RAM %02d%%\n' "$cpu" "$ram"
