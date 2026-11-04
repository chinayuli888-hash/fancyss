# webtest-tool binaries

The `webtest-tool-v0.1.1-linux-armv5te` and
`webtestctl-v0.1.1-linux-armv5te` in this fork come from
`chinayuli888-hash/webtest-tool` commit
`e31f400dce35c740c11cba486541df659f5618e9`.
Build them with Zig 0.15.2 from that checkout:

```bash
bash scripts/build-release.sh --no-upx armv5te
```

Despite the `armv5te` filenames, these builds use the ARMv6 CPU target
`arm1176jzf_s` with `arm-linux-musleabi` and `ReleaseSmall`; they were tested
on the ARMv7 K3 and must not be assumed to work on ARMv5 CPUs. Other targets
remain at their previous builds.
