#!/bin/sh

# Run one bounded HTTPS download through the currently running SOCKS proxy.
# A temporary loopback HTTP-to-SOCKS bridge is used because some router curl
# builds silently ignore proxy options.
URL=${1:-https://fsn1-speed.hetzner.com/100MB.bin}
XRAY=/koolshare/bin/xray
WGET=/usr/sbin/wget
BYTES=524288
LOCK=/tmp/fancyss-proxy-speed.lock
TEMP=/tmp/fancyss-proxy-speed.$$
BRIDGE_PID=""
WGET_PID=""
WATCH_PID=""

[ "$#" -le 1 ] || { echo 'error: invalid speed test request' >&2; exit 2; }
case "$URL" in https://*) ;; *) echo 'error: speed test URL must use HTTPS' >&2; exit 2 ;; esac
[ -x "$XRAY" ] && [ -x "$WGET" ] || { echo 'error: required speed test tools are unavailable' >&2; exit 1; }
netstat -lnt 2>/dev/null | awk '$4 == "127.0.0.1:23456" { found=1 } END { exit !found }' || {
	echo 'error: current proxy is not running' >&2; exit 1;
}

umask 077
exec 9>"$LOCK" || { echo 'error: cannot create speed test lock' >&2; exit 1; }
flock -n 9 || { echo 'error: another speed test is running' >&2; exit 1; }
mkdir "$TEMP" || { echo 'error: cannot create speed test directory' >&2; exit 1; }
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
	echo 'error: local speed test port is busy' >&2; exit 1
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
[ "$READY" = 1 ] || { echo 'error: local speed test bridge did not start' >&2; exit 1; }

START=$(awk '{printf "%.0f", $1 * 1000}' /proc/uptime)
( ulimit -f 2048 || exit 1
  exec env -i PATH=/usr/sbin:/usr/bin:/bin:/sbin HOME="$TEMP" https_proxy="http://127.0.0.1:$PORT" \
	"$WGET" --no-config --no-hsts -e use_proxy=on -S -t 1 -T 12 --max-redirect=0 \
	--header='Range: bytes=0-524287' --header='Accept-Encoding: identity' \
	-O "$TEMP/body" "$URL" 2>"$TEMP/wget.log"
) 9>&- &
WGET_PID=$!
( sleep 18; kill "$WGET_PID" 2>/dev/null ) 9>&- >/dev/null 2>&1 &
WATCH_PID=$!
wait "$WGET_PID"
WGET_STATUS=$?
WGET_PID=""
kill "$WATCH_PID" 2>/dev/null
WATCH_PID=""
END=$(awk '{printf "%.0f", $1 * 1000}' /proc/uptime)
ACTUAL=$(wc -c <"$TEMP/body" | tr -d '[:space:]')
if [ "$WGET_STATUS" -ne 0 ] || [ "$ACTUAL" != "$BYTES" ] || ! awk -v port="$PORT" '
	{ line=tolower($0); sub(/\r$/, "", line) }
	index(line, "connecting to 127.0.0.1:" port "... connected.") { proxy=1 }
	line ~ /^[[:space:]]*http\/[0-9.]+ 206([[:space:]]|$)/ { status=1 }
	line ~ /^[[:space:]]*content-range:[[:space:]]*bytes 0-524287\/[0-9*]+[[:space:]]*$/ { range=1 }
	END { exit !(proxy && status && range) }
' "$TEMP/wget.log"; then
	echo 'error: proxy download failed or returned an incomplete response' >&2
	exit 1
fi
ELAPSED=$((END - START))
[ "$ELAPSED" -gt 0 ] || { echo 'error: invalid speed test duration' >&2; exit 1; }
awk -v bytes="$BYTES" -v ms="$ELAPSED" 'BEGIN { printf "download_mbps=%.2f bytes=%d seconds=%.2f\n", bytes * 8 / (ms * 1000), bytes, ms / 1000 }'
