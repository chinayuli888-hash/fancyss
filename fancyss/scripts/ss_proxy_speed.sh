#!/bin/sh

# One bounded download through the current fancyss SOCKS5 listener.
# Usage: ss_proxy_speed.sh [HTTPS URL supporting a 4 MiB byte range]

URL=${1:-https://fsn1-speed.hetzner.com/100MB.bin}
CURL_BIN=${FANCYSS_CURL_BIN:-/koolshare/bin/curl-fancyss}
SOCKS_ADDR=127.0.0.1:23456
BYTES=4194304

[ "$#" -le 1 ] || {
	printf 'error: usage: %s [HTTPS URL]\n' "$0" >&2
	exit 2
}
case "$URL" in
	https://*) ;;
	*) printf 'error: speed test URL must use HTTPS\n' >&2; exit 2 ;;
esac
[ -x "$CURL_BIN" ] || {
	printf 'error: curl-fancyss is unavailable: %s\n' "$CURL_BIN" >&2
	exit 2
}

umask 077
TMP_DIR=/tmp/fancyss_proxy_speed.$$
mkdir "$TMP_DIR" || {
	printf 'error: cannot create speed test temporary directory\n' >&2
	exit 1
}
BODY=$TMP_DIR/body
ERR=$TMP_DIR/error
trap 'rm -f "$BODY" "$ERR"; rmdir "$TMP_DIR" 2>/dev/null' 0
trap 'exit 130' 1 2 3 15

# Remote DNS and an explicit proxy keep this request on the current node.
RESULT=$(LC_ALL=C "$CURL_BIN" --silent --show-error --location --max-redirs 2 \
	--proto '=https' --proto-redir '=https' \
	--socks5-hostname "$SOCKS_ADDR" --noproxy '' \
	--range 0-4194303 --max-filesize "$BYTES" \
	--connect-timeout 5 --max-time 20 \
	--header 'Accept-Encoding: identity' \
	--output "$BODY" --write-out '%{http_code} %{time_total}' \
	"$URL" 2>"$ERR")
CURL_RC=$?
if [ "$CURL_RC" -ne 0 ]; then
	DETAIL=$(sed -n '1p' "$ERR")
	[ -n "$DETAIL" ] || DETAIL='connection or download failed'
	printf 'error: proxy download failed (curl exit %s): %s\n' "$CURL_RC" "$DETAIL" >&2
	exit 1
fi

case "$RESULT" in
	*' '*) HTTP_CODE=${RESULT%% *}; ELAPSED_SECONDS=${RESULT#* } ;;
	*) printf 'error: curl did not report HTTP status and elapsed time\n' >&2; exit 1 ;;
esac
[ "$HTTP_CODE" = 206 ] || {
	printf 'error: endpoint did not honor the 4 MiB Range request (HTTP %s, expected 206)\n' "$HTTP_CODE" >&2
	exit 1
}
ACTUAL_BYTES=$(wc -c < "$BODY" | tr -d '[:space:]')
[ "$ACTUAL_BYTES" = "$BYTES" ] || {
	printf 'error: incomplete Range response (%s bytes, expected %s)\n' "$ACTUAL_BYTES" "$BYTES" >&2
	exit 1
}
MBPS=$(LC_ALL=C awk -v seconds="$ELAPSED_SECONDS" -v bytes="$BYTES" '
	BEGIN {
		if (seconds !~ /^[0-9]+([.][0-9]+)?$/ || seconds + 0 <= 0) exit 1
		printf "%.2f", bytes * 8 / (seconds * 1000000)
	}
') || {
	printf 'error: invalid elapsed time from curl: %s\n' "$ELAPSED_SECONDS" >&2
	exit 1
}
printf 'download_mbps=%s bytes=%s seconds=%s\n' "$MBPS" "$BYTES" "$ELAPSED_SECONDS"
