# Laptop inventory

Fill in before installing. `hostname`, `gdk_scale`, `wifi_driver` are the answers chezmoi asks for.

| hostname | Model | CPU | RAM | Disk | Panel | Wi-Fi chipset | wifi_driver | gdk_scale | role | Notes (kernel, quirks) |
|---|---|---|---|---|---|---|---|---|---|---|
| dell-01 | Dell … | | | | 1920×1080 | | none | 1 | daily | |
| lenovo-01 | Lenovo … | | | | | | none | 1 | daily | |
| | | | | | | | | | | |

How to find the Wi-Fi chipset from the Omarchy live USB: `lspci -nn | grep -i net` (PCIe) or `lsusb` (USB). Broadcom BCM43xx → `broadcom`, Intel/Realtek/Qualcomm → `none`.
