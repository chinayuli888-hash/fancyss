# xapi-tool binaries

Source project:
- `tool/xapi-tool`

Current bundled version:
- `v0.2.1`

Purpose:
- lightweight Xray API client for fancyss hot paths
- first targets are `StatsService.QueryStats` and selected routing / handler commands
- intended to replace slow one-shot `xray api ...` calls

Packaging note:
- `bin-arm/xapi-tool-armv6` is a non-UPX ARMv6 build for old-kernel ARMv6/ARMv7 routers; ARMv5 is not supported by this binary
- upstream `v0.2.1` artifacts for the other architectures are UPX-packed
- verified on GS7 (`aarch64`) and TUF-AX3000 (`armv7a` / `armv7hf`) that the bundled binaries can start normally

The ARMv6 build was tested on the K3's Linux 2.6.36.4 kernel. It uses
`tool/xapi-tool` commit `5e6d726aae371b370d07da10e4d004f927026916`
with `k3-armv6.patch` applied (libc linking and bounded socket waits), and
Zig 0.15.2. From the repository root, apply it with
`git -C tool/xapi-tool apply --unidiff-zero ../../binaries/xapi-tool/k3-armv6.patch`,
then build inside `tool/xapi-tool` with
`zig build -Dtarget=arm-linux-musleabi -Dcpu=arm1176jzf_s -Doptimize=ReleaseSmall`.
It is not UPX-compressed. Its hash is recorded in `SHA256SUMS-v0.2.1`.
