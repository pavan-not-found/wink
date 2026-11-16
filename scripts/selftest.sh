#!/usr/bin/env bash
# End-to-end check against a running Wink: drives every state through wink:// URLs
# and confirms the power assertion is held or released each time.
#
#   defaults write app.wink.mac debugSnapshots -bool true   (once)
#   open dist/Wink.app && scripts/selftest.sh
#
# It doesn't touch lid-closed sleep, so it never asks for a password.
set -uo pipefail
OUT="/tmp/wink-snapshots"
pass=0; fail=0

state() { local n; n="$(echo "$1" | tr -cd "[:alnum:]-")"; open -g "wink://debug-snapshot?name=$n"; sleep 0.8; cat "$OUT/$n/state.txt"; }
held()  { pmset -g assertions | grep -c 'Wink is keeping your Mac awake' || true; }
check() {
  local name="$1" want_mode="$2" want_held="$3"
  local s; s="$(state "$name")"
  local h; h="$(held)"
  if [[ "$s" == *"mode=$want_mode"* && "$h" == "$want_held" ]]; then
    printf "  ✓ %-22s %s\n" "$name" "$s"; pass=$((pass+1))
  else
    printf "  ✗ %-22s %s (assertion=%s, wanted mode=%s assertion=%s)\n" "$name" "$s" "$h" "$want_mode" "$want_held"; fail=$((fail+1))
  fi
}

pgrep -x Wink >/dev/null || { echo "Start Wink first."; exit 1; }
[[ "$(defaults read app.wink.mac debugSnapshots 2>/dev/null)" == "1" ]] || { echo "Run: defaults write app.wink.mac debugSnapshots -bool true"; exit 1; }
defaults write app.wink.mac lidClosed -bool false

echo "Wink self-test"
open -g "wink://start?for=2h";      sleep 1; check "start 2h" running 1
open -g "wink://pause";             sleep 1; check "pause" paused 0
open -g "wink://resume";            sleep 1; check "resume" running 1
open -g "wink://extend?by=1h";      sleep 1; check "extend 1h" running 1
open -g "wink://start?for=forever"; sleep 1; check "forever" running 1
open -g "wink://stop";              sleep 1; check "stop" off 0
open -g "wink://start?until=08:00"; sleep 1; check "until 08:00" running 1
open -g "wink://start?for=20s";     sleep 1; check "start 20s" running 1
sleep 21;                                    check "20s ran out" off 0
# Nonsense from a web page must be ignored, never crash, never start anything
open -g "wink://start?for=1e300";   sleep 1; check "reject 1e300" off 0
open -g "wink://start?for=infinity"; sleep 1; check "reject infinity" off 0
open -g "wink://start?for=999999999"; sleep 1; check "reject huge" off 0
open -g "wink://start?for=1h";      sleep 1
open -g "wink://extend?by=1e300";   sleep 1; check "reject huge extend" running 1
open -g "wink://stop";              sleep 1; check "still alive" off 0

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
