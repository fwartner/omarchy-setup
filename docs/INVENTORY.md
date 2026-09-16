# Laptop inventory

One row per machine. `hostname`, `gdk_scale`, `wifi_driver` and `role` are the
answers chezmoi asks for on first run, so filling this in first means you can
answer them without guessing.

| hostname | Model | CPU | RAM | Disk | Panel | Wi-Fi | wifi_driver | gdk_scale | role |
|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | `none` | 1 | `daily` |
| | | | | | | | `none` | 1 | `spare` |

Boot the Omarchy live USB on each machine and run this — it prints everything
the table needs:

```sh
printf '=== %s ===\nCPU:  %s\nRAM:  %s\n' "$(cat /sys/class/dmi/id/product_name)" \
  "$(lscpu | sed -n 's/^Model name: *//p')" "$(free -h | awk '/^Mem:/{print $2}')"
echo "DISK:"; lsblk -d -o NAME,SIZE,ROTA,TRAN | sed 's/^/  /'
echo "WIFI:"; lspci -nn | grep -iE 'network|wireless' | sed 's/^/  /'
```

`ROTA=0` is an SSD, `1` a spinning disk. The `[vendor:device]` ID on the WIFI
line identifies the chipset, which is what decides `wifi_driver`.

## Choosing the per-machine values

**`gdk_scale`** — `2` on HiDPI panels, `1` on 1080p and below. Omarchy assumes
`2`; on a 13" 1080p or a 1366×768 panel everything will be enormous until you
set `1`.

**`wifi_driver`** — `none` means the mainline kernel driver works, which is the
common case (Intel `iwlwifi`, Qualcomm `ath10k`, Realtek `rtw88`). Only reach
for a DKMS override when the mainline driver actually misbehaves — a card that
associates and then drops with beacon loss is the usual sign. Adding a DKMS
module you do not need buys you a rebuild on every kernel update for nothing.

**`role`** — `daily` gets everything. `spare` drops the GUI-heavy packages (see
`SPARE_SKIP` in `scripts/pkglist.sh`), which matters on a machine with 4 GB
where a browser plus an editor already swaps. Both roles get the full terminal
toolchain, the mesh, the vault and backups; the difference is only desktop
weight.

## Per-model notes

Keep hardware quirks here rather than in the runbook, which stays generic.
Things worth recording: BIOS settings that are not obvious (SATA mode, Secure
Boot, virtualisation), whether suspend and resume work, fingerprint reader
support, and anything that needed a kernel parameter.
