# Laptop inventory

`hostname`, `gdk_scale`, `wifi_driver`, `role` are the answers chezmoi asks for on first run.

| hostname | Model | CPU | RAM | Disk | Panel | Wi-Fi | wifi_driver | gdk_scale | role |
|---|---|---|---|---|---|---|---|---|---|
| `latitude-7310` | Dell Latitude 7310 (P33S) | Comet Lake i5/i7-10x10U | soldered, verify (8/16 GB) | M.2 NVMe | 13.3" FHD 1920×1080 | Intel AX201 / AC 9560 / AC 9462 (iwlwifi, mainline) | `none` | 1 | `daily` |
| `v130-15igm` | Lenovo V130-15IGM (81HL) | Gemini Lake Celeron N4000 (verify: N4100/N5000 SKUs exist) | 4 GB, **one DDR4 SO-DIMM slot, upgrade to 8/16 GB** | 2.5" SATA (SSD? verify) + M.2 slot | 15.6" TN 1366×768 | Realtek RTL8821CE **or** Qualcomm QCA9377 **or** Intel 3165 — check `lspci -nn` | `none` (mainline rtw88/ath10k/iwlwifi); `rtl8821ce` only if Wi-Fi drops | 1 | `spare` |

Fill in the "verify" cells from the Omarchy live USB: `lscpu | grep 'Model name'`, `free -h`, `lsblk -d -o NAME,SIZE,ROTA,TRAN`, `lspci -nn | grep -iE 'net|wireless'`.

## Per-model notes

### Dell Latitude 7310 — daily driver

- Ubuntu-certified hardware (cert 202003-27782); UHD 620, I2C touchpad, ALC3254 audio, Intel Wi-Fi all mainline.
- **BIOS: SATA Operation defaults to RAID (Intel RST) → set to AHCI/NVMe**, otherwise the installer sees no disk. Secure Boot off. Enable VT-x.
- Fingerprint reader (in the power button) is Broadcom ControlVault 3 (BCM58200), not supported by upstream libfprint. Optional: AUR `libfprint-2-tod1-broadcom` after a `fwupdmgr` firmware update; known to disappear after suspend/resume. Skip unless you want it.
- RAM is soldered: whatever it has is what it keeps.
- s2idle suspend; no known 7310-specific suspend issues.

### Lenovo V130-15IGM (81HL) — spare / agent runner

- Realistic verdict: with N4000 + 4 GB, Hyprland + Chromium + VS Code will swap. Fine for terminal, SSH, Neovim, herdr with one agent, headless work. A ~20 € 8 GB SO-DIMM (16 GB works on Gemini Lake) plus a SATA SSD turns it into a usable light daily machine; the 768p TN panel stays.
- BIOS via Novo pinhole button or F2; F12 boot menu. Boot Mode UEFI, Secure Boot off (Security tab).
- Wi-Fi depends on the SKU. Realtek RTL8821CE runs on mainline `rtw_8821ce` (kernel ≥ 5.16); if it disconnects with beacon loss, set `wifi_driver = rtl8821ce` (installs AUR `rtl8821ce-dkms-git`, blacklists `rtw_8821ce`, adds `pcie_aspm.policy=performance`). QCA9377 (ath10k) and Intel 3165 (iwlwifi) need nothing.
- No eMMC on this model, so LUKS + Btrfs on the SATA disk is normal.
- `role = spare` drops the GUI-heavy packages (DBeaver, Bruno, Telegram, Bitwarden, Harlequin, Posting) from both the install and the nightly update — see `scripts/pkglist.sh`, which both `bootstrap.sh` and `scripts/update-all.sh` call so they cannot disagree. It does **not** touch `.chezmoiignore`, which branches only on `wifi_driver`, and it does not affect Syncthing folders. Obsidian cannot be skipped: `omarchy-base.packages` installs it on every machine.
