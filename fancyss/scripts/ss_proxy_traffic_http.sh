#!/bin/sh

# Return non-resetting Xray outbound counters to the authenticated UI.
source /koolshare/scripts/base.sh

case "$1" in
	''|*[!0-9]*) http_response 'unavailable|request' >/dev/null 2>&1; exit 1 ;;
esac

respond() {
	http_response "$1" >/dev/null 2>&1
}

[ "$(dbus get ss_basic_enable 2>/dev/null)" = "1" ] || { respond 'unavailable|disabled'; exit 0; }
XAPI=/koolshare/bin/xapi-tool
case "$(uname -m)" in
	armv6*|armv7*|armv8*|aarch64*)
		[ ! -x /koolshare/bin/xapi-tool-armv6 ] || XAPI=/koolshare/bin/xapi-tool-armv6 ;;
esac
[ -x "$XAPI" ] || { respond 'unavailable|tool'; exit 0; }

PID=""
for candidate in $(pidof xray 2>/dev/null); do
	command_line=$(tr '\000' ' ' < "/proc/$candidate/cmdline" 2>/dev/null)
	case "$command_line" in
		*'/koolshare/ss/xray.json'*) PID=$candidate; break ;;
	esac
done
[ -n "$PID" ] || { respond 'unavailable|core'; exit 0; }
START=$(awk '{print $22}' "/proc/$PID/stat" 2>/dev/null)
case "$START" in ''|*[!0-9]*) respond 'unavailable|core'; exit 0 ;; esac

MODE=$(dbus get ss_basic_mode 2>/dev/null)
if [ "$MODE" = "7" ]; then
	PORT=10085
else
	PORT=10086
fi
DATA=$("$XAPI" stats-query --server "127.0.0.1:$PORT" --pattern 'outbound>>>' 2>/dev/null) || { respond 'unavailable|api'; exit 0; }
COUNTS=$(printf '%s\n' "$DATA" | /koolshare/bin/jq -r '
  [.stats | to_entries[] | select(.key == "proxy" or (.key | test("^proxy[0-9]+$")))] as $s
  | if ($s | length) == 0 then empty
    else (([$s[].value.uplink] | add) | tostring) + "|" + (([$s[].value.downlink] | add) | tostring) end
' 2>/dev/null)
case "$COUNTS" in *'|'*'|'*|'' ) respond 'unavailable|stats'; exit 0 ;; *'|'*) ;; *) respond 'unavailable|stats'; exit 0 ;; esac
UP=${COUNTS%%|*}
DOWN=${COUNTS#*|}
case "$UP" in ''|*[!0-9]*) respond 'unavailable|stats'; exit 0 ;; esac
case "$DOWN" in ''|*[!0-9]*) respond 'unavailable|stats'; exit 0 ;; esac
UPTIME=$(awk '{printf "%.0f", $1 * 1000}' /proc/uptime 2>/dev/null)
case "$UPTIME" in ''|*[!0-9]*) respond 'unavailable|clock'; exit 0 ;; esac
respond "ok|$PID|$START|$UPTIME|$COUNTS"
