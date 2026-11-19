<div align="center">

# 🐧 Omarchy on Bay Trail

**Make the latest [Omarchy](https://omarchy.org) boot on old Intel Bay Trail devices with 32-bit UEFI and a 64-bit CPU.**

*Pipo X9 · Asus EeeBook X205TA · any Intel Atom Z3735F / Z37xx device*

[![ShellCheck](https://github.com/kevinnguyenhoang91/omarchy-baytrail-post-installation/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/kevinnguyenhoang91/omarchy-baytrail-post-installation/actions/workflows/shellcheck.yml)
[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=archlinux&logoColor=white)](https://archlinux.org)
[![Omarchy](https://img.shields.io/badge/Omarchy-Hyprland-58E1FF?logo=hyprland&logoColor=white)](https://omarchy.org)
[![UEFI](https://img.shields.io/badge/UEFI-IA32_(32--bit)-orange)](#-why-this-exists)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Stars](https://img.shields.io/github/stars/kevinnguyenhoang91/omarchy-baytrail-post-installation?style=social)](https://github.com/kevinnguyenhoang91/omarchy-baytrail-post-installation/stargazers)

[Quick Start](#-quick-start-one-liner) •
[Full Guide](#-full-installation-guide) •
[What the Script Does](#%EF%B8%8F-what-the-script-does) •
[Troubleshooting](#-troubleshooting) •
[FAQ](#-faq)

</div>

---

## 🤔 Why this exists

Bay Trail devices pair a **64-bit (`x86_64`) CPU** with **32-bit UEFI (`IA32`) firmware** — an odd combo most distros don't expect.

The good news: both the **Omarchy ISO** and the **Arch Linux ISO** ship `BOOTIA32.EFI`, so they boot and the Omarchy installer finishes fine on the internal eMMC.

The bad news: **the freshly installed system will not boot** after the first reboot, because:

| # | Problem | Result |
|---|---------|--------|
| 1 | The installed system uses **64-bit UKIs / bootloader entries** | 32-bit firmware can't load them |
| 2 | Mainline `linux` hits a **null-pointer crash in `intel_pmic_power_handler`** while probing the eMMC controller (`sdhci_acpi 80860F14:00`) | Kernel panic, no root device |

This repo fixes both with **one script**: it switches you to `linux-lts`, installs **32-bit GRUB (`i386-efi`)**, rebuilds a classic initramfs, and tunes swap for 2 GB RAM.

## ✨ Features

- 🥾 **32-bit UEFI GRUB** installed to the fallback path `EFI/BOOT/BOOTIA32.EFI`
- 🛡️ **`linux-lts`** kernel replaces the crashing mainline kernel
- 🔐 **Auto-detects LUKS** and writes the correct `cryptdevice=UUID=…` cmdline
- 💾 Early **eMMC + Btrfs + dm-crypt** modules baked into the initramfs
- 🧠 **3 GB zstd zram** + **4 GB swapfile in a dedicated `/swap` Btrfs subvolume** (snapshot-safe) to survive on 2 GB RAM
- 🔤 Big, readable **Terminus TTY font** for tiny high-DPI screens
- ♻️ **Idempotent** — safe to re-run

## 💻 Tested devices

| Device | CPU | Screen | RAM / Storage | Status |
|--------|-----|--------|---------------|--------|
| **Pipo X9** (mini-PC) | Atom Z3735F | 8.9" 1920×1200 | 2 GB / 32 GB eMMC | ✅ Working |
| **Asus EeeBook X205TA** | Atom Z3735F | 11.6" 1366×768 | 2 GB / 32–64 GB eMMC | ✅ Working |

> Other Bay Trail devices with 32-bit UEFI (Z3735D/G, Z3740, Z3775…) should work the same way. PRs adding devices are welcome!

---

## 🧭 How it works

```mermaid
flowchart LR
    A[💿 USB 1<br/>Omarchy ISO] -->|install to eMMC| B[❌ First boot fails]
    B --> C[💿 USB 2<br/>Arch Linux ISO]
    C -->|Wi-Fi + unlock + mount| D[arch-chroot /mnt]
    D -->|curl … &#124; bash| E[🔧 postinstall script]
    E --> F[✅ Omarchy boots]
```

## 📋 Requirements

- A Bay Trail device with **32-bit UEFI**
- **Two USB drives** (≥ 4 GB each)
  - **USB 1:** official [Omarchy ISO](https://omarchy.org)
  - **USB 2:** latest official [`archlinux-x86_64.iso`](https://archlinux.org/download/)
- A **Wi-Fi network** (needed by the rescue shell to download packages)

> [!NOTE]
> Both ISOs already contain `BOOTIA32.EFI`. **No manual copying of `bootia32.efi` is needed.**

---

## 🚀 Quick Start (one-liner)

Already installed Omarchy and are now booted into the **Arch Linux USB (USB 2)**? Do this:

**1. Connect to Wi-Fi**

```bash
iwctl station wlan0 scan
iwctl station wlan0 get-networks
iwctl station wlan0 connect "YOUR_WIFI_SSID"   # enter the passphrase when prompted
ping -c 3 archlinux.org
```

> [!TIP]
> Not `wlan0`? Run `iwctl device list` to find your interface name.

**2. Unlock, mount, and chroot**

```bash
cryptsetup open /dev/mmcblk0p2 cryptroot              # skip if not encrypted
mount -o subvol=@ /dev/mapper/cryptroot /mnt          # unencrypted: /dev/mmcblk0p2
mount /dev/mmcblk0p1 /mnt/boot
arch-chroot /mnt
```

**3. Run the script directly with `curl`** (inside the chroot)

```bash
curl -fsSL https://raw.githubusercontent.com/kevinnguyenhoang91/omarchy-baytrail-post-installation/main/omarchy-baytrail-postinstall.sh | bash
```

<details>
<summary>🔍 Prefer to read the script before running it? (recommended)</summary>

```bash
curl -fsSL -o /root/postinstall.sh https://raw.githubusercontent.com/kevinnguyenhoang91/omarchy-baytrail-post-installation/main/omarchy-baytrail-postinstall.sh
less /root/postinstall.sh
bash /root/postinstall.sh
```

</details>

**4. Exit and reboot**

```bash
exit
umount -R /mnt
cryptsetup close cryptroot   # skip if not encrypted
reboot
```

Unplug USB 2 when the screen goes black. **Omarchy should now boot.** 🎉

---

## 📖 Full Installation Guide

### Hardware considerations (2 GB RAM / 32 GB eMMC)

- **RAM (2 GB DDR3L, soldered):** use `zram` (1.5× RAM ≈ 3 GB) + a 4 GB swapfile in its own `/swap` Btrfs subvolume so updates and browsing don't trigger OOM freezes.
- **Storage (32/64 GB eMMC):** wipe the factory partitions and use **Btrfs with `zstd` compression** (Omarchy's default).
- **Kernel:** always use **`linux-lts`** to avoid the `intel_pmic_power_handler` eMMC crash.
- **Networking:** Wi-Fi works out of the box with `iwctl` in the Arch live USB on both devices.

### Phase 1 — Prepare two USB drives

1. **USB 1:** flash the official Omarchy ISO.
2. **USB 2:** flash the latest official `archlinux-x86_64.iso`.

### Phase 2 — Install Omarchy (USB 1)

1. Enter firmware setup (**`Del`/`Esc`** on Pipo X9, **`F2`** on X205TA).
2. Disable **Secure Boot** and **Fast Boot / Fast Startup**, then boot **USB 1**.
3. Install Omarchy onto the internal eMMC (`/dev/mmcblk0`).
4. After it reboots, **it will fail to boot** — this is expected.
5. Power off and insert **USB 2**.

### Phase 3 — Rescue shell & chroot (USB 2)

1. Boot **USB 2**. At the `root@archiso ~ #` prompt, enlarge the font and the live RAM disk:

   ```bash
   setfont latarcyrheb-sun32
   mount -o remount,size=1G /run/archiso/cowspace
   ```

2. Connect to Wi-Fi:

   ```bash
   iwctl station wlan0 scan
   iwctl station wlan0 get-networks
   iwctl station wlan0 connect "YOUR_WIFI_SSID"
   ping -c 3 archlinux.org
   ```

3. Check partitions with `lsblk -f` — usually `mmcblk0p1` = `vfat` `/boot`, `mmcblk0p2` = `crypto_LUKS` or `btrfs` `/`.

4. Unlock and mount:

   ```bash
   # Encrypted (Omarchy default)
   cryptsetup open /dev/mmcblk0p2 cryptroot
   mount -o subvol=@ /dev/mapper/cryptroot /mnt

   # — or — unencrypted Btrfs
   mount -o subvol=@ /dev/mmcblk0p2 /mnt
   ```

5. Mount `/boot` and chroot:

   ```bash
   mount /dev/mmcblk0p1 /mnt/boot
   arch-chroot /mnt
   ```

### Phase 4 — Post-install fixes (inside chroot)

Run the [one-liner](#-quick-start-one-liner), or follow the manual steps below.

<details>
<summary><b>🛠️ Manual steps (click to expand)</b></summary>

#### 1. Install `linux-lts` and tools, remove mainline `linux`

```bash
pacman -Syu linux-lts linux-lts-headers grub efibootmgr terminus-font zram-generator
pacman -R linux
```

#### 2. Kernel image, early modules, and non-UKI initramfs

```bash
cp /usr/lib/modules/*-lts/vmlinuz /boot/vmlinuz-linux-lts

mkdir -p /etc/mkinitcpio.conf.d
cat << 'EOF' > /etc/mkinitcpio.conf.d/99-baytrail.conf
MODULES+=(dm_mod dm_crypt btrfs mmc_block sdhci sdhci_acpi sdhci_pci)
EOF
```

> [!IMPORTANT]
> Omarchy already has `encrypt` before `filesystems` in `HOOKS`. Only append `MODULES` — **don't overwrite `HOOKS`**.

Edit `/etc/mkinitcpio.d/linux-lts.preset`:

```ini
ALL_kver="/boot/vmlinuz-linux-lts"
PRESETS=('default' 'fallback')

default_image="/boot/initramfs-linux-lts.img"
#default_uki="/efi/EFI/Linux/arch-linux-lts.efi"

fallback_image="/boot/initramfs-linux-lts-fallback.img"
#fallback_uki="/efi/EFI/Linux/arch-linux-lts-fallback.efi"
fallback_options="-S autodetect"
```

Build and verify:

```bash
mkinitcpio -P
ls -lh /boot/vmlinuz* /boot/initramfs*
```

#### 3. Install 32-bit GRUB

```bash
findmnt /boot
grub-install --target=i386-efi --efi-directory=/boot --bootloader-id=GRUB --removable
```

If encrypted, get the **outer** `crypto_LUKS` UUID:

```bash
blkid -t TYPE=crypto_LUKS -s UUID -o value
```

Set it in `/etc/default/grub` (not `PARTUUID`, not the inner Btrfs UUID):

```text
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet cryptdevice=UUID=YOUR-CRYPTO-LUKS-UUID:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@"
```

Generate and check:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
grep "linux.*/vmlinuz" /boot/grub/grub.cfg
```

#### 4. TTY font, zram, and swap subvolume

```bash
# ter-132n for Pipo X9; ter-124n or ter-128n for X205TA
echo "FONT=ter-132n" > /etc/vconsole.conf

cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 1.5
compression-algorithm = zstd
swap-priority = 100
EOF

# 4 GB swapfile inside a dedicated Btrfs subvolume
btrfs subvolume create /swap
btrfs filesystem mkswapfile --size 4g --uuid clear /swap/swapfile
echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab
```

> [!WARNING]
> Don't put the swapfile directly in `/` (the `@` subvolume). Btrfs refuses to snapshot a subvolume with an active swapfile, which breaks Omarchy's snapper snapshots.

</details>

### Phase 5 — Display scaling after first boot

Open a terminal (`Super + Return`) and edit `~/.config/hypr/monitors.conf`:

| Device | Panel | Setting |
|--------|-------|---------|
| Pipo X9 | 8.9" 1920×1200 | `monitor=,preferred,auto,1.5` (or `1.75`) |
| Asus X205TA | 11.6" 1366×768 | `monitor=,preferred,auto,1` |

---

## ⚙️ What the script does

| Step | Action |
|------|--------|
| **0** | Checks it runs as root and that `/boot` is mounted |
| **1/6** | Installs `linux-lts`, headers, `grub`, `efibootmgr`, `terminus-font`, `zram-generator`; removes mainline `linux` |
| **2/6** | Copies `vmlinuz-linux-lts` to `/boot`, adds early Bay Trail modules, switches the preset from UKI to classic `initramfs`, runs `mkinitcpio -P` |
| **3/6** | Installs `i386-efi` GRUB to `/boot/EFI/BOOT/BOOTIA32.EFI`, writes the LUKS/Btrfs kernel cmdline, runs `grub-mkconfig` |
| **4/6** | Sets the TTY font to `ter-132n` |
| **5/6** | Configures zstd zram at 1.5× RAM |
| **6/6** | Creates a `/swap` Btrfs subvolume, a 4 GB swapfile inside it, and adds it to `/etc/fstab` |

At the end it prints the files in `/boot` and the active GRUB `linux` lines so you can check the result.

---

## 🩺 Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Kernel panic / null pointer in `intel_pmic_power_handler` | Mainline kernel regression on Bay Trail `sdhci_acpi` eMMC | Use **`linux-lts`** and remove `linux` |
| `/boot/vmlinuz-linux-lts` missing / empty GRUB menu | Kernel only in `/usr/lib/modules/*-lts/` and UKI preset still active | `cp /usr/lib/modules/*-lts/vmlinuz /boot/vmlinuz-linux-lts`, switch preset to `default_image`, run `mkinitcpio -P` and `grub-mkconfig -o /boot/grub/grub.cfg` |
| `Name must not contain '/' character` at LUKS prompt | Mapper name contains `/` | Use `cryptdevice=UUID=<CRYPTO-LUKS-UUID>:cryptroot` |
| Emergency shell: `no resume device found` / `cryptroot not found` | Missing `dm_crypt`/`btrfs` in initramfs, or wrong LUKS UUID | See below ⬇️ |

<details>
<summary><b>Emergency shell recovery</b></summary>

**Boot right now:**

```bash
modprobe dm_mod dm_crypt btrfs
cryptsetup open /dev/mmcblk0p2 cryptroot
mount -o subvol=@ /dev/mapper/cryptroot /sysroot
exit
```

**Fix permanently:** make sure `/etc/mkinitcpio.conf.d/99-baytrail.conf` contains
`MODULES+=(dm_mod dm_crypt btrfs mmc_block sdhci sdhci_acpi sdhci_pci)`, check `cryptdevice=UUID=<CRYPTO-LUKS-UUID>:cryptroot` in `/etc/default/grub`, then:

```bash
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
```

</details>

---

## ❓ FAQ

<details>
<summary><b>Do I need to copy <code>bootia32.efi</code> to the USB manually?</b></summary>

No. Current Omarchy and Arch Linux ISOs already include `BOOTIA32.EFI`.
</details>

<details>
<summary><b>Why two USB drives?</b></summary>

The Omarchy USB installs the system. The Arch USB gives you a rescue shell to `arch-chroot` in and fix the bootloader and kernel before the first real boot.
</details>

<details>
<summary><b>Can I re-run the script?</b></summary>

Yes. Packages use `--needed`, and the swap subvolume, swapfile and `fstab` steps check whether they've already run.
</details>

<details>
<summary><b>Why a separate <code>/swap</code> subvolume instead of <code>/swapfile</code>?</b></summary>

Omarchy snapshots the root (`@`) subvolume with snapper. Btrfs can't snapshot a subvolume that holds an active swapfile, so a `/swapfile` in `@` makes snapshots fail. A nested `/swap` subvolume is left out of `@` snapshots, so swap and snapshots work together. It mounts automatically with `@`, so no extra `fstab` mount line is needed.
</details>

<details>
<summary><b>Will kernel updates break booting?</b></summary>

No. The `linux-lts` preset now builds a classic initramfs, and GRUB lives at the firmware fallback path. If you change `/etc/default/grub`, run `grub-mkconfig -o /boot/grub/grub.cfg`.
</details>

---

## 🤝 Contributing

Got another Bay Trail device working? Found a bug? [Open an issue](https://github.com/kevinnguyenhoang91/omarchy-baytrail-post-installation/issues) or send a PR. Please run `shellcheck` on script changes.

## 🙏 Credits

- [Omarchy](https://omarchy.org) by DHH
- [Arch Linux](https://archlinux.org) and the [ArchWiki](https://wiki.archlinux.org)

## 📄 License

[MIT](LICENSE) © 2026 Kha Hoang Nguyen

<div align="center">

**If this saved your old tablet from the drawer, consider giving it a ⭐**

</div>
