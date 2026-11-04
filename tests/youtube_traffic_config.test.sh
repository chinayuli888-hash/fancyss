#!/bin/sh
set -eu

HELPER=${1:-/koolshare/scripts/ss_youtube_traffic_config.sh}
JQ=${FSS_YOUTUBE_JQ:-/koolshare/bin/jq}
XRAY=${FSS_YOUTUBE_XRAY:-/koolshare/bin/xray}
TMP=/tmp/fss-youtube-config-test.$$
umask 077
mkdir "$TMP"
trap 'rm -f "$TMP"/*; rmdir "$TMP"' 0 1 2 3 15

"$JQ" -n '{
  inbounds:[{listen:"127.0.0.1",port:23456,protocol:"socks",settings:{}},
    {listen:"127.0.0.1",port:3333,protocol:"dokodemo-door",settings:{address:"127.0.0.1",port:443,network:"tcp"}}],
  outbounds:[{tag:"proxy",protocol:"freedom",settings:{}}],
  stats:{}, policy:{system:{statsOutboundUplink:true,statsOutboundDownlink:true}}
}' > "$TMP/base.json"

cp "$TMP/base.json" "$TMP/current.json"
sh "$HELPER" "$TMP/current.json"
"$JQ" -e --slurpfile original "$TMP/base.json" '
  .outbounds[0] == $original[0].outbounds[0] and
  .outbounds[1] == ($original[0].outbounds[0] | .tag="fss-youtube-video") and
  .routing.rules[0].domain == ["domain:googlevideo.com"] and
  .routing.rules[0].outboundTag == "fss-youtube-video" and
  .inbounds[1].sniffing.routeOnly == true and
  (.inbounds[1].sniffing.destOverride | index("tls") != null)
' "$TMP/current.json" >/dev/null
before=$(md5sum "$TMP/current.json" | cut -d' ' -f1)
sh "$HELPER" "$TMP/current.json"
[ "$before" = "$(md5sum "$TMP/current.json" | cut -d' ' -f1)" ]

"$JQ" '.routing.rules=[{type:"field",domain:["example.com"],outboundTag:"proxy"}]' "$TMP/base.json" > "$TMP/custom.json"
before=$(md5sum "$TMP/custom.json" | cut -d' ' -f1)
sh "$HELPER" "$TMP/custom.json"
[ "$before" = "$(md5sum "$TMP/custom.json" | cut -d' ' -f1)" ]

"$JQ" '.inbounds[1].sniffing={enabled:true,destOverride:["http"]}' "$TMP/base.json" > "$TMP/sniff.json"
before=$(md5sum "$TMP/sniff.json" | cut -d' ' -f1)
sh "$HELPER" "$TMP/sniff.json"
[ "$before" = "$(md5sum "$TMP/sniff.json" | cut -d' ' -f1)" ]

cp "$TMP/base.json" "$TMP/failure.json"
before=$(md5sum "$TMP/failure.json" | cut -d' ' -f1)
if FSS_YOUTUBE_XRAY=/bin/false sh "$HELPER" "$TMP/failure.json"; then
  echo 'FAIL: invalid Xray config validator was accepted' >&2
  exit 1
fi
[ "$before" = "$(md5sum "$TMP/failure.json" | cut -d' ' -f1)" ]
echo 'PASS: add video route, preserve settings, idempotency, custom routing and failure rollback'
