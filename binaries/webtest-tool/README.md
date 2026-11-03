# webtest-tool binaries

The ARMv5 `webtest-tool-v0.1.1-linux-armv5te` and
`webtestctl-v0.1.1-linux-armv5te` in this fork come from
`chinayuli888-hash/webtest-tool` commit
`e31f400dce35c740c11cba486541df659f5618e9`.
Build them with Zig 0.15.2 from that checkout:

```bash
bash scripts/build-release.sh --no-upx armv5te
```

This uses `arm-linux-musleabi`, CPU `arm1176jzf_s`, and `ReleaseSmall`.
Other targets remain at their previous builds.
