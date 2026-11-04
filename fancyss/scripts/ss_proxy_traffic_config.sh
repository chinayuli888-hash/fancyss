#!/bin/sh

# Add a local statistics-only API to ordinary Xray configurations. Leave
# custom APIs and unsupported configurations untouched.
CONFIG=${1:-/koolshare/ss/xray.json}
JQ=/koolshare/bin/jq
XRAY=/koolshare/bin/xray
PORT=10086
TEMP="${CONFIG}.traffic.$$"

[ -s "$CONFIG" ] && [ -x "$JQ" ] && [ -x "$XRAY" ] || exit 1
if "$JQ" -e '.api.tag == "fss-traffic-api" and .api.listen == "127.0.0.1:10086" and
  ((.api.services // []) | index("StatsService") != null) and (.stats != null) and
  .policy.system.statsOutboundUplink == true and .policy.system.statsOutboundDownlink == true' "$CONFIG" >/dev/null 2>&1; then
	exit 0
fi
if ! "$JQ" -e '(.api == null or (.api.tag == "fss-traffic-api" and .api.listen == "127.0.0.1:10086")) and
  (([.outbounds[]? | select(.tag == "proxy")] | length == 1) or
   ((.outbounds | length == 1) and ((.outbounds[0].tag // "") == "") and
    (.outbounds[0].protocol == "trojan" or .outbounds[0].protocol == "hysteria"))) and
  ([.outbounds[]? | select(.tag == "fss-traffic-api")] | length == 0)' "$CONFIG" >/dev/null 2>&1; then
	exit 0
fi
if netstat -lnt 2>/dev/null | awk '$4 ~ /:10086$/ { found=1 } END { exit !found }'; then
	exit 1
fi

umask 077
trap 'rm -f "$TEMP"' 0 1 2 3 15
"$JQ" '
  (if (.outbounds | length == 1) and ((.outbounds[0].tag // "") == "") then .outbounds[0].tag = "proxy" else . end)
  | .api = {"tag":"fss-traffic-api", "listen":"127.0.0.1:10086", "services":["StatsService"]}
  | .stats = (.stats // {})
  | .policy = (.policy // {})
  | .policy.system = (.policy.system // {})
  | .policy.system.statsOutboundUplink = true
  | .policy.system.statsOutboundDownlink = true
' "$CONFIG" > "$TEMP" || exit 1
"$XRAY" run -test -format json -c "$TEMP" >/dev/null 2>&1 || exit 1
mv -f "$TEMP" "$CONFIG" || exit 1
exit 0
