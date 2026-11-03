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

The ARMv5 `status-tool-v0.1.3-linux-armv5te` in this fork comes from
`chinayuli888-hash/status-tool` commit `5b17780e8b8790f8516f9cc0cd618d0f6f215d10`.
Build it with Zig 0.15.2 from that checkout:

```bash
bash scripts/build-release.sh --no-upx armv5te
```

This uses `arm-linux-musleabi`, CPU `arm1176jzf_s`, and `ReleaseSmall`.
Only the ARMv5 `status-tool` artifact is replaced here; the other targets and
`statusctl` remain at their previous builds.
