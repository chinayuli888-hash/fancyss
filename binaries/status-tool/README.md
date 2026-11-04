# status-tool binaries

Source project:

- `tool/status-tool`

Purpose:

- native HTTP status probe tool for fancyss
- intended to replace the heavy shell + curl based `ss_status.sh` / `ss_status_main.sh` path
- includes `statusctl`, a thin Unix socket control client for `status-tool serve`

Artifacts in this directory are generated from:

```bash
make -C binaries update_status_tool
```

The `status-tool-v0.1.3-linux-armv5te` artifact in this fork comes from
`chinayuli888-hash/status-tool` commit `5b17780e8b8790f8516f9cc0cd618d0f6f215d10`.
Build it with Zig 0.15.2 from that checkout:

```bash
bash scripts/build-release.sh --no-upx armv5te
```

Despite the `armv5te` filename, this build uses the ARMv6 CPU target
`arm1176jzf_s` with `arm-linux-musleabi` and `ReleaseSmall`; it was tested on
the ARMv7 K3 and must not be assumed to work on ARMv5 CPUs. Only this
`status-tool` artifact is replaced; other targets and `statusctl` remain at
their previous builds.
