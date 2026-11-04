#!/bin/sh

# Check YouTube itself through the current local SOCKS proxy. This is a
# connectivity check; video transfer rates are sampled independently.
XRAY=/koolshare/bin/xray
WGET=/usr/sbin/wget
LOCK=/tmp/fancyss-proxy-speed.lock
TEMP=/tmp/fancyss-youtube-check.$$
BRIDGE_PID=""
WGET_PID=""
WATCH_PID=""

[ "$#" -eq 0 ] || { echo 'error: invalid YouTube check request' >&2; exit 2; }
[ -x "$XRAY" ] && [ -x "$WGET" ] || { echo 'error: required check tools are unavailable' >&2; exit 1; }
netstat -lnt 2>/dev/null | awk '$4 == "127.0.0.1:23456" { found=1 } END { exit !found }' || {
	echo 'error: current proxy is not running' >&2; exit 1;
}

umask 077
exec 9>"$LOCK" || { echo 'error: cannot create check lock' >&2; exit 1; }
flock -n 9 || { echo 'error: another check is running' >&2; exit 1; }
mkdir "$TEMP" || { echo 'error: cannot create check directory' >&2; exit 1; }
cleanup() {
	[ -z "$WATCH_PID" ] || kill "$WATCH_PID" 2>/dev/null
	[ -z "$WGET_PID" ] || kill "$WGET_PID" 2>/dev/null
	[ -z "$BRIDGE_PID" ] || kill "$BRIDGE_PID" 2>/dev/null
	rm -f "$TEMP/config.json" "$TEMP/bridge.log" "$TEMP/wget.log" "$TEMP/body"
	rmdir "$TEMP" 2>/dev/null
}
trap cleanup 0
trap 'exit 130' 1 2 3 15

PORT=$((24000 + $$ % 10000))
if netstat -lnt 2>/dev/null | awk -v p=":$PORT" 'index($4,p) && $4 ~ (p "$") { found=1 } END { exit !found }'; then
	echo 'error: local check port is busy' >&2; exit 1
fi
cat >"$TEMP/config.json" <<-EOF
{"log":{"loglevel":"none"},"inbounds":[{"listen":"127.0.0.1","port":$PORT,"protocol":"http","settings":{}}],"outbounds":[{"protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":23456}]}}]}
EOF
"$XRAY" run -c "$TEMP/config.json" >"$TEMP/bridge.log" 2>&1 9>&- &
BRIDGE_PID=$!
READY=0
for unused in 1 2 3 4 5 6 7 8 9 10 11 12; do
	kill -0 "$BRIDGE_PID" 2>/dev/null || break
	if netstat -lntp 2>/dev/null | awk -v endpoint="127.0.0.1:$PORT" -v owner="$BRIDGE_PID/xray" '$4 == endpoint && $NF == owner { found=1 } END { exit !found }'; then
		READY=1; break
	fi
	sleep 1
done
[ "$READY" = 1 ] || { echo 'error: local check bridge did not start' >&2; exit 1; }

START=$(awk '{printf "%.0f", $1 * 1000}' /proc/uptime)
env -i PATH=/usr/sbin:/usr/bin:/bin:/sbin HOME="$TEMP" https_proxy="http://127.0.0.1:$PORT" \
	"$WGET" --no-config --no-hsts -e use_proxy=on -S -t 1 -T 8 --max-redirect=0 \
	-O "$TEMP/body" 'https://www.youtube.com/generate_204' 2>"$TEMP/wget.log" 9>&- &
WGET_PID=$!
( sleep 15; kill "$WGET_PID" 2>/dev/null ) 9>&- >/dev/null 2>&1 &
WATCH_PID=$!
wait "$WGET_PID"
WGET_STATUS=$?
WGET_PID=""
kill "$WATCH_PID" 2>/dev/null
WATCH_PID=""
END=$(awk '{printf "%.0f", $1 * 1000}' /proc/uptime)
if [ "$WGET_STATUS" -ne 0 ] || ! awk -v port="$PORT" '
	{ line=tolower($0); sub(/\r$/, "", line) }
	index(line, "connecting to 127.0.0.1:" port "... connected.") { proxy=1 }
	line ~ /^[[:space:]]*http\/[0-9.]+ 204([[:space:]]|$)/ { status=1 }
	END { exit !(proxy && status) }
' "$TEMP/wget.log"; then
	echo 'error: YouTube connectivity check failed' >&2
	exit 1
fi
ELAPSED=$((END - START))
[ "$ELAPSED" -gt 0 ] || { echo 'error: invalid check duration' >&2; exit 1; }
awk -v ms="$ELAPSED" 'BEGIN { printf "youtube_status=ok seconds=%.2f\n", ms / 1000 }'
