#!/bin/sh

# HTTP API entry point for browsers without the software center WebSocket.
# The core test bounds its bridge startup and 512 KiB download.
source /koolshare/scripts/base.sh

case "$1" in
	''|*[!0-9]*) http_response 'error: invalid speed test request' >/dev/null 2>&1; exit 1 ;;
esac

RESULT=$(sh /koolshare/scripts/ss_proxy_speed.sh 2>&1)
STATUS=$?
RESULT=$(printf '%s\n' "$RESULT" | sed -n '1p' | cut -c 1-180)
if [ "$STATUS" -ne 0 ]; then
	case "$RESULT" in
		error:*) ;;
		*) RESULT='error: proxy download failed' ;;
	esac
fi
[ -n "$RESULT" ] || RESULT='error: proxy speed test returned no result'
http_response "$RESULT" >/dev/null 2>&1
