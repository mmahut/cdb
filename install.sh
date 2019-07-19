#!/usr/bin/env bash 
set -e

# Colors are for cool kids
header()  { echo -e "\n\033[1m$@\033[0m"; }
error()   { echo -e " \033[1;31m*\033[0m  $@"; }
bold() { echo -e "\033[1m$@\033[0m"; }

print_banner() {
  echo 
  echo " _________________ "
  echo "/  __ \  _  \ ___ \  Welcome to"
  echo "| /  \/ | | | |_/ /    Corporate Desktop"
  echo "| |   | | | | ___ \        Installer"
  echo "| \__/\ |/ /| |_/ /"
  echo  "\____/___/ \____/ "
  echo
  echo
  echo " We are going to install NixOS on this computer."
  echo "         ALL DATA WILL BE LOST !!! "
  echo
  echo
  echo
  read -p "Do you understand? (Yes/No): " confirm < /dev/tty && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
}

find_install_device() {
  if [ -b /dev/nvme0n1 ]; then
    export INST_DEVICE="/dev/nvme0n1";
  elif [ -b /dev/sda ]; then
    export INST_DEVICE="/dev/sda";
  else
    echo "Installation device not found."
    read -p "Please specify the installation device manually: " -r < /dev/tty
    export INST_DEVICE=$REPLY
    if [ -b $INST_DEVICE ]; then
      echo "$INST_DEVICE is valid, using it."
    else
      error "$INST_DEVICE is not valid, leaving."
    fi
  fi
}

ask_for_username() {
  read -p "[?] Please enter user's first name: " INST_FIRSTNAME < /dev/tty
  read -p "[?] Please enter user's second name: " INST_SECONDNAME < /dev/tty
  export INST_FIRSTNAME="${INST_FIRSTNAME,,}"
  export INST_SECONDNAME="${INST_SECONDNAME,,}"
  export INST_USERNAME="${INST_FIRSTNAME:0:1}${INST_SECONDNAME:0:7}"
}

run_parted() {
  read -p "[?] We are going to to run parted on $(bold $INST_DEVICE). Is this okay? [Yes/No] " confirm < /dev/tty && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
  echo -n "[-] Partitioning $INST_DEVICE... "
  wipefs -a $INST_DEVICE >/dev/null 2>&1
  parted $INST_DEVICE -- mklabel gpt >/dev/null 2>&1
  parted $INST_DEVICE -- mkpart ESP fat32 1MiB 512MiB set 1 boot on >/dev/null 2>&1
  parted $INST_DEVICE mkpart primary ext4 537M 100% set 2 lvm on >/dev/null 2>&1
  echo " done."
}

run_cryptsetup(){
  echo -n "[-] Encrypting the disk... "
  INST_PASSWD=$(diceware -s 1 -n 2);
  INST_PASSWD_SHA512=$(mkpasswd  -m sha-512 -s <<< ${INST_PASSWD})
  echo -n $INST_PASSWD | cryptsetup -q luksFormat ${INST_DEVICE}2 -
  echo -n $INST_PASSWD | cryptsetup luksOpen ${INST_DEVICE}2 enc-pv -d -
  echo "done."
}

run_fssetup(){
  echo -n "[-] Setting up KVM... "
  pvcreate /dev/mapper/enc-pv >/dev/null
  vgcreate vg /dev/mapper/enc-pv >/dev/null
  lvcreate -n swap vg -L 8G >/dev/null
  lvcreate -n root vg -l 100%FREE >/dev/null
  echo "done."
  echo -n "[-] Formating filesystems... "
  mkfs.fat -F 32 -n boot ${INST_DEVICE}1 >/dev/null 2>&1
  mkfs.ext4 -L root /dev/vg/root >/dev/null >/dev/null 2>&1
  mkswap -L swap /dev/vg/swap >/dev/null 2>&1
  echo "done."
  echo -n "[-] Mouting filesystems... "
  mount /dev/disk/by-label/root /mnt
  mkdir -p /mnt/boot
  mount /dev/disk/by-label/boot /mnt/boot
  swapon /dev/disk/by-label/swap >/dev/null
  echo "done."
}

run_nixossetup(){
  echo -n "[-] Generating NixOS configurations... "
  nixos-generate-config --root /mnt >/dev/null 2>&1
  mv /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix-old
  wget -q https://raw.githubusercontent.com/mmahut/cdb/master/configuration-template.nix -O /mnt/etc/nixos/configuration.nix
  sed -i "s~##device##~${INST_DEVICE}~g" /mnt/etc/nixos/configuration.nix
  sed -i "s~##username##~${INST_USERNAME}~g" /mnt/etc/nixos/configuration.nix
  sed -i "s~##rootpasswd##~${INST_PASSWD_SHA512/\//\\/}~g" /mnt/etc/nixos/configuration.nix
  echo "done."
}

run_nixosinstall(){
  echo "[-] Running nixos-install... "
  nixos-install --no-root-passwd
}

print_finish(){
  echo
  echo
  echo Pleas take a note of following:
  echo
  echo 
  bold Username: $INST_USERNAME
  bold Password: $INST_PASSWD
  echo
  echo Help the user to change this password.
  echo
}

# Let's bring the band together
clear
print_banner
ask_for_username
find_install_device
run_parted
run_cryptsetup
run_fssetup
run_nixossetup
run_nixosinstall
print_finish
