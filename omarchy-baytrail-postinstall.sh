#!/usr/bin/env bash
set -euo pipefail

# Omarchy Post-Install Script for Intel Bay Trail 32-bit UEFI Devices
# Tested on: Pipo X9, Asus EeeBook X205TA (Intel Atom Z3735F)
# Run this script INSIDE arch-chroot (/mnt) from the Arch Linux rescue USB.
#
# https://github.com/kevinnguyenhoang91/omarchy-baytrail-post-installation

if [[ $EUID -ne 0 ]]; then
   echo "Error: Please run this script as root inside arch-chroot."
   exit 1
fi

if ! findmnt /boot > /dev/null; then
   echo "Error: /boot is not mounted. Mount your EFI partition to /boot before running this script."
   exit 1
fi

echo "==> [1/6] Installing linux-lts, GRUB, terminus-font, and zram-generator..."
pacman -Syu --noconfirm --needed linux-lts linux-lts-headers grub efibootmgr terminus-font zram-generator

if pacman -Qi linux > /dev/null 2>&1; then
   echo "==> Removing mainline 'linux' kernel (prevents Bay Trail eMMC crash)..."
   pacman -R --noconfirm linux
fi

echo "==> [2/6] Copying vmlinuz-linux-lts to /boot and configuring mkinitcpio..."
VMLINUZ_SRC=$(find /usr/lib/modules -maxdepth 2 -name "vmlinuz" | grep -- "-lts" | head -n 1 || true)
if [[ -z "$VMLINUZ_SRC" ]]; then
   echo "Error: Could not find vmlinuz under /usr/lib/modules/*-lts/"
   exit 1
fi
cp "$VMLINUZ_SRC" /boot/vmlinuz-linux-lts

# Append early Bay Trail eMMC, Btrfs, and LUKS modules without overriding Omarchy's default HOOKS
mkdir -p /etc/mkinitcpio.conf.d
cat << 'EOF' > /etc/mkinitcpio.conf.d/99-baytrail.conf
MODULES+=(dm_mod dm_crypt btrfs mmc_block sdhci sdhci_acpi sdhci_pci)
EOF

cat << 'EOF' > /etc/mkinitcpio.d/linux-lts.preset
# mkinitcpio preset file for the 'linux-lts' package (32-bit UEFI GRUB compatible)

ALL_kver="/boot/vmlinuz-linux-lts"

PRESETS=('default' 'fallback')

default_image="/boot/initramfs-linux-lts.img"
#default_uki="/efi/EFI/Linux/arch-linux-lts.efi"

fallback_image="/boot/initramfs-linux-lts-fallback.img"
#fallback_uki="/efi/EFI/Linux/arch-linux-lts-fallback.efi"
fallback_options="-S autodetect"
EOF

mkinitcpio -P

echo "==> [3/6] Installing 32-bit UEFI GRUB (i386-efi)..."
grub-install --target=i386-efi --efi-directory=/boot --bootloader-id=GRUB --removable

LUKS_UUID=$(blkid -t TYPE=crypto_LUKS -s UUID -o value | head -n 1 || true)
if [[ -n "$LUKS_UUID" ]]; then
   echo "==> Detected encrypted root (crypto_LUKS UUID: $LUKS_UUID). Updating GRUB cmdline..."
   NEW_CMDLINE="loglevel=3 quiet cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@"
   if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
      sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${NEW_CMDLINE}\"|" /etc/default/grub
   else
      echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${NEW_CMDLINE}\"" >> /etc/default/grub
   fi
else
   echo "==> Unencrypted root detected. Ensuring rootflags=subvol=@ is set in GRUB..."
   if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub && ! grep -q 'subvol=@' /etc/default/grub; then
      sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"|GRUB_CMDLINE_LINUX_DEFAULT="\1 rootflags=subvol=@"|' /etc/default/grub
   fi
fi

grub-mkconfig -o /boot/grub/grub.cfg

echo "==> [4/6] Configuring larger TTY console font (ter-132n)..."
echo "FONT=ter-132n" > /etc/vconsole.conf

echo "==> [5/6] Configuring 3 GB compressed zram (ram * 1.5)..."
cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 1.5
compression-algorithm = zstd
swap-priority = 100
EOF

echo "==> [6/6] Creating 4 GB swapfile in a dedicated Btrfs subvolume (/swap)..."
# A nested subvolume is excluded from snapper snapshots of '@', so an active
# swapfile never blocks Omarchy's root snapshots.
if [[ -e /swap ]] && ! btrfs subvolume show /swap > /dev/null 2>&1; then
   echo "Error: /swap exists but is not a Btrfs subvolume. Move it aside and re-run."
   exit 1
fi
if [[ ! -e /swap ]]; then
   btrfs subvolume create /swap
fi
if [[ ! -f /swap/swapfile ]]; then
   btrfs filesystem mkswapfile --size 4g --uuid clear /swap/swapfile
fi
if ! grep -q '^/swap/swapfile' /etc/fstab; then
   echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab
fi

echo ""
echo "=================================================================="
echo "Setup complete! Verification:"
ls -lh /boot/EFI/BOOT/BOOTIA32.EFI /boot/vmlinuz-linux-lts /boot/initramfs-linux-lts.img
echo ""
echo "Active GRUB Linux boot lines:"
grep "linux.*/vmlinuz" /boot/grub/grub.cfg
echo "=================================================================="
echo "Next steps:"
echo "  1. Type 'exit' to leave arch-chroot"
echo "  2. Run 'umount -R /mnt' (and 'cryptsetup close cryptroot' if encrypted)"
echo "  3. Run 'reboot' and unplug the Arch Linux USB drive"
