#!/bin/sh

source /koolshare/scripts/base.sh
case "$1" in
	''|*[!0-9]*) http_response 'error: invalid YouTube check request' >/dev/null 2>&1; exit 1 ;;
esac
RESULT=$(sh /koolshare/scripts/ss_youtube_check.sh 2>&1)
STATUS=$?
RESULT=$(printf '%s\n' "$RESULT" | sed -n '1p' | cut -c 1-180)
if [ "$STATUS" -ne 0 ]; then
	case "$RESULT" in error:*) ;; *) RESULT='error: YouTube check failed' ;; esac
fi
[ -n "$RESULT" ] || RESULT='error: YouTube check returned no result'
http_response "$RESULT" >/dev/null 2>&1
