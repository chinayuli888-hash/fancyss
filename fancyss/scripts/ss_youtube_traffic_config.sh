#!/bin/sh

# Add separate counters for recognized YouTube video CDN connections only on
# simple, statistics-enabled Xray configurations. Existing custom routing and
# sniffing are intentionally left untouched.
CONFIG=${1:-/koolshare/ss/xray.json}
JQ=${FSS_YOUTUBE_JQ:-/koolshare/bin/jq}
XRAY=${FSS_YOUTUBE_XRAY:-/koolshare/bin/xray}
TEMP="${CONFIG}.youtube.$$"

[ -s "$CONFIG" ] && [ -x "$JQ" ] && [ -x "$XRAY" ] || exit 1
if "$JQ" -e '
  ([.outbounds[]? | select(.tag == "fss-youtube-video")] | length == 1) and
  ([.routing.rules[]? | select(.outboundTag == "fss-youtube-video" and
    ((.domain // []) | index("domain:googlevideo.com") != null))] | length == 1)
' "$CONFIG" >/dev/null 2>&1; then
	exit 0
fi

if ! "$JQ" -e '
  (.stats != null) and .policy.system.statsOutboundUplink == true and
  .policy.system.statsOutboundDownlink == true and
  ((.outbounds // []) | length == 1) and .outbounds[0].tag == "proxy" and
  (((.routing // {}).rules // []) | length == 0) and
  ([.inbounds[]? | select(.protocol == "dokodemo-door")] | length == 1) and
  ([.inbounds[]? | select(.protocol == "dokodemo-door" and .sniffing != null)] | length == 0)
' "$CONFIG" >/dev/null 2>&1; then
	exit 0
fi

umask 077
trap 'rm -f "$TEMP"' 0 1 2 3 15
"$JQ" '
  .outbounds[0] as $proxy
  | .outbounds += [($proxy | .tag = "fss-youtube-video")]
  | .routing = (.routing // {})
  | .routing.domainStrategy = (.routing.domainStrategy // "AsIs")
  | .routing.rules = [{"type":"field", "domain":["domain:googlevideo.com"], "outboundTag":"fss-youtube-video"}]
  | .inbounds |= map(if .protocol == "dokodemo-door" then
      .sniffing = {"enabled":true, "destOverride":["tls","quic"], "routeOnly":true}
    else . end)
' "$CONFIG" > "$TEMP" || exit 1
"$XRAY" run -test -format json -c "$TEMP" >/dev/null 2>&1 || exit 1
mv -f "$TEMP" "$CONFIG" || exit 1
exit 0
