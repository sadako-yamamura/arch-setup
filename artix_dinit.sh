#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo " (X) ERROR: Must run as root"
  exit 1
fi
# UEFI Check
if [[ ! -d /sys/firmware/efi ]]; then
    echo " (X) ERROR: System is not booted in UEFI mode."
    echo "     Reboot and boot the Artix installer in UEFI mode."
    exit 1
fi

cleanup() {
  umount -lR /mnt 2>/dev/null || true
}
trap cleanup EXIT

# ========================================= FLAGS
flag_dboot=false
flag_kde=false
flag_lxqt=false
while getopts "dkl" opt; do
  case $opt in
    d)
      flag_dboot=true
      ;;
    k)
      flag_kde=true
      ;;
    l)
      flag_lxqt=true
      ;;
    *)
      echo " (i) NO Desktop Environment will be installed"
      ;;
  esac
done

read -rp " - Enter your desired Username: " USERNAME
read -srp " - Password: " PASSWORD
echo
read -srp " - Confirm password: " PASSWORD2
echo

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo " (X) Username and password are required."
  exit 1
fi

if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
  echo " (X) Passwords do not match."
  exit 1
fi

echo "========================================================="
echo "================== ARTIX INSTALL SCRIPT =================="
echo "========================================================="
umount -R /mnt 2>/dev/null || true

# ========================================= MIRRORS
# NOTE:  artix mirrors are extremely slow/bad
#        will only use the few that actually work
cat > /etc/pacman.d/mirrorlist << 'EOF'
Server = https://mirror2.artixlinux.org/$repo/os/$arch
Server = https://mirror3.artixlinux.org/repos/$repo/os/$arch
EOF
pacman -Syy
#cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
#pacman -S pacman-contrib --noconfirm
#TMP="/tmp/mirrors.txt"
#grep '^Server = https' /etc/pacman.d/mirrorlist > "$TMP"
#echo " (i) Optimizing mirrors..."
#rankmirrors -n 5 "$TMP" | tee /etc/pacman.d/mirrorlist
#echo " (i) Optimized HTTPS mirrors applied"
#pacman -Syyu --noconfirm

# ========================================= DISK PARTITIONING
echo " ========== Available disks:"
lsblk -o NAME,SIZE,FSUSE%,TYPE,FSTYPE,MOUNTPOINTS,UUID
read -p " - Disk to install Artix to -! DATA WILL BE DELETED !- (ex: nvme0n1): " DISK

echo " ========== Partitioning disk..."
pacman -S parted --noconfirm
wipefs -af /dev/$DISK
parted /dev/$DISK --script \
 mklabel gpt \
 mkpart ESP fat32 1MiB 1GiB \
 set 1 esp on \
 mkpart primary ext4 1GiB 100%

echo " ========== Formatting..."
mkfs.fat -F32 -n ESP /dev/${DISK}1 || true
mkfs.fat -F32 -n ESP /dev/${DISK}p1 || true
# Not actual FDE as leaves boot, but less complex, compatible. Should have secboot tho
# cryptsetup luksFormat -h sha512 /dev/${DISK]p2, enter twice passwd
# cryptsetup open /dev/${DISK]p2 root
# mkfs.ext4 /dev/mapper/root, instead
mkfs.ext4 -F -L ROOT /dev/${DISK}2 || true
mkfs.ext4 -F -L ROOT /dev/${DISK}p2 || true

echo " ========== Mounting filesystem..."
# /dev/mapper/root, instead of p2
mount -o noatime,commit=60 /dev/${DISK}2 /mnt || true
mount -o noatime,commit=60 /dev/${DISK}p2 /mnt || true
tune2fs -m 0 /dev/${DISK}2 || true
tune2fs -m 0 /dev/${DISK}p2 || true

mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg}
mount /dev/${DISK}1 /mnt/boot || true
mount /dev/${DISK}p1 /mnt/boot || true

# ========================================= CORE PACKAGES
mkdir -p /mnt/etc
echo " ========== Installing base system..."
basestrap /mnt \
 base base-devel linux linux-firmware \
 bash-completion man-db man-pages less \
 sudo \
 htop nano vim git wget \
 fastfetch \
 grub efibootmgr \
 artix-archlinux-support archlinux-keyring \
 rust \
 mtools dosfstools \
 --noconfirm
# basestrap /mnt cryptsetup

echo " ========== Enabling Arch repositories"
mkdir -p /mnt/etc/pacman.d
cat > /mnt/etc/pacman.d/mirrorlist-arch << 'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
EOF
artix-chroot /mnt /bin/bash -c '
  if ! grep -q "^\[extra\]" /etc/pacman.conf; then
    cat <<'"'"'EOF'"'"' >> /etc/pacman.conf

# Arch
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
  fi
'
 
# ========================================= FSTAB
echo " ========== Generating fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab

# ========================================= LOCALES
echo " ========== Setting local timezone and en_US.UTF-8 locales"
dinitctl start ntpd
artix-chroot /mnt /bin/bash -c "
 ln -sf /usr/share/zoneinfo/UTC /etc/localtime
 hwclock --systohc
 sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
 locale-gen
 echo 'LANG=en_US.UTF-8' > /etc/locale.conf
 echo 'KEYMAP=us' > /etc/vconsole.conf
"

# ========================================= NETWORK
echo " ========== Setting hostname"
artix-chroot /mnt /bin/bash -c "
 echo artix > /etc/hostname
 echo '127.0.1.1        artix.localdomain artix' >> /etc/hosts
"

# ========================================= USERS
printf 'root:%s\n' "$PASSWORD" | artix-chroot /mnt /bin/bash -c 'chpasswd'
echo " ========== Creating user"
artix-chroot /mnt /bin/bash -c 'useradd -m -G wheel,audio,video,storage,power -s /bin/bash "$1"' _ "$USERNAME"
printf '%s:%s\n' "$USERNAME" "$PASSWORD" | artix-chroot /mnt /bin/bash -c 'chpasswd'
artix-chroot /mnt /bin/bash -c "sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers"
# unset PASSWORD PASSWORD2

echo " ========== Installing paru"
artix-chroot /mnt /bin/bash -c '
  su - "$1" -c "
    set -e
    cd ~
    rm -rf paru
    git clone --depth 1 https://aur.archlinux.org/paru.git
    cd paru
    makepkg --noconfirm --needed
  "
  pacman -U --noconfirm /home/$1/paru/*.pkg.tar.*
  rm -rf /home/$1/paru
' _ "$USERNAME"

# ========================================= HARDWARE AND DRIVERS
echo " ========== Installing CPU microcode"
if lscpu | grep -i intel; then
 basestrap /mnt intel-ucode --noconfirm
elif lscpu | grep -i amd; then
 basestrap /mnt amd-ucode --noconfirm
fi
# Latest NVIDIA drivers, but conflicts with Steam from pacman
echo " ========== Checking for NVIDIA GPU"
if lspci | grep -i nvidia; then
 basestrap /mnt linux-headers nvidia-utils nvidia-settings nvidia-dkms --noconfirm
fi

# Modify /mnt/etc/default/grub
# Uncomment #GRUB_ENABLE_CRYPTODISK=y (really?)
# Change GRUB_CMDLINE_LINUX=""
# to     GRUB_CMDLINE_LINUX="cryptdevice=/dev/nvme0n1p2:root"
# Modify /mnt/etc/mkinitcpio.conf
# Change HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
# to     HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)

# If encryption, ignore qat_6xxx warning
artix-chroot /mnt /bin/bash -c "
 echo 'FONT=lat9u-16' >> /etc/vconsole.conf
 mkinitcpio -P
"

# ========================================= BOOTLOADER
echo " ========== Installing GRUB bootloader"
artix-chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"

if $flag_dboot; then
  read -p " (i) Second EFI partition ((ex: nvme1n1p1)): " PART_DBOOT
  artix-chroot /mnt /bin/bash -c '
    mount --mkdir "/dev/$1" /mnt/efi2
    pacman -S --noconfirm os-prober ntfs-3g
    sed -i "s/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/" /etc/default/grub
    grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub || printf "%s\n" "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
  ' _ "$PART_DBOOT"
fi

artix-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"

# ========================================= DESKTOP
# LXQt
if $flag_lxqt; then
  echo " (i) INSTALLING LXQt"
  : # pavucontrol-qt was previously left as a bare command here.
  basestrap /mnt \
    lxqt pcmanfm-qt kitty \
    sddm breeze-icons \
    networkmanager network-manager-applet \
    xorg-server xorg-xinit xdg-utils \
    ttf-dejavu gvfs \
   --noconfirm
fi
   # lxqt-archiver \
   # kate libstatgrab screengrab \
   # xdg-dbus-proxy xlibre-input-libinput \
   # openbox \
   
# KDE
if $flag_kde; then
  echo " (i) INSTALLING KDE"
  basestrap /mnt \
   plasma-desktop kitty dolphin kscreen kwrite \
   bluedevil plasma-nm plasma-pa powerdevil \
   kwayland-integration noto-fonts noto-fonts-emoji fontconfig \
   sddm sddm-dinit \
   breeze-gtk \
   --noconfirm
fi

# ========================================= SERVICES
# Installation of basic services
# Ignore 'Enabling dinit user spawn service' error message
# System
basestrap /mnt \
 dinit dinit-user-spawn \
 dbus-dinit \
 acpid-dinit \
 bluez-dinit \
 cronie-dinit \
 cups-dinit \
 elogind-dinit \
 metalog metalog-dinit \
 networkmanager-dinit \
 sddm-dinit \
 zramen-dinit \
 --noconfirm

# Pipewire (user)
basestrap /mnt \
 pipewire \
 pipewire-alsa \
 pipewire-dinit \
 pipewire-pulse \
 pipewire-pulse-dinit \
 wireplumber \
 wireplumber-dinit \
 --noconfirm

# Enabling system services
artix-chroot /mnt /bin/bash -c "
 ln -sf /etc/dinit.d/acpid /etc/dinit.d/boot.d/
 ln -sf /etc/dinit.d/bluetoothd /etc/dinit.d/boot.d/
 ln -sf /etc/dinit.d/cronie /etc/dinit.d/boot.d/
 ln -sf /etc/dinit.d/cupsd /etc/dinit.d/boot.d/
 ln -sf /etc/dinit.d/dbus /etc/dinit.d/boot.d/
 ln -sf /etc/dinit.d/elogind /etc/dinit.d/boot.d/
 ln -sf /etc/dinit.d/metalog /etc/dinit.d/boot.d/
 ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/
 ln -sf /etc/dinit.d/zramen /etc/dinit.d/boot.d/
"
# SDDM for both LXQt and KDE
if  [ "$flag_kde" = true ] || [ "$flag_lxqt" = true ]; then
  artix-chroot /mnt /bin/bash -c "ln -sf /etc/dinit.d/sddm /etc/dinit.d/boot.d/"
fi

# Enabling user services
artix-chroot /mnt /bin/bash -e <<EOF
  user_home=\$(getent passwd "$USERNAME" | cut -d: -f6)
  mkdir -p "\$user_home/.config/dinit.d/boot.d"
  ln -sf /etc/dinit.d/user/dbus "\$user_home/.config/dinit.d/boot.d/dbus"
  ln -sf /etc/dinit.d/user/pipewire "\$user_home/.config/dinit.d/boot.d/pipewire"
  ln -sf /etc/dinit.d/user/pipewire-pulse "\$user_home/.config/dinit.d/boot.d/pipewire-pulse"
  ln -sf /etc/dinit.d/user/wireplumber "\$user_home/.config/dinit.d/boot.d/wireplumber"
  chown -R "$USERNAME:$USERNAME" "\$user_home/.config"
EOF
# (i) TODO
# polkit,ufw,lib32
# flag for other utility

# ========================================= FINISHING INSTALLATION
echo " ========== Finished and rebooting in 5 seconds..."
umount -lR /mnt
sleep 5
reboot
