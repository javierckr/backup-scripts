#!/bin/sh

# Backup installed packages list

# Determine the package manager
# openWRT uses opkg
if [ -f /etc/openwrt_release ]; then
    opkg list-installed > /etc/installed_packages.txt

# Arch Linux uses pacman
elif [ -f /etc/arch-release ]; then
    pacman -Qqe > /etc/installed_packages.txt

# Gentoo uses emerge
elif [ -f /etc/gentoo-release ]; then
    emerge -ep world > /etc/installed_packages.txt

# Debian uses apt 
elif [ -f /etc/debian_version ]; then
    dpkg --get-selections > /etc/installed_packages.txt
fi
