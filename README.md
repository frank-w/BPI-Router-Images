## Prerequisite

1. Build U-boot https://github.com/brucerry/BPI-Router-Uboot
    - bpi-r3_emmc.img.gz

2. Build Linux https://github.com/brucerry/BPI-Router-Linux
    - bpi-r3_6.12.47-main.tar.gz
    
## Setup the Workspace in Native Linux Distro

It can be shown that x86 WSL2/Docker would fail the `buildchroot` and `partprobe`/`loopdev` processes.

The build is tested in Debian/Ubuntu/LinuxMint system:

```
cat /etc/os-release

NAME="Linux Mint"
VERSION="21.1 (Vera)"
ID=linuxmint
ID_LIKE="ubuntu debian"
PRETTY_NAME="Linux Mint 21.1"
VERSION_ID="21.1"
HOME_URL="https://www.linuxmint.com/"
SUPPORT_URL="https://forums.linuxmint.com/"
BUG_REPORT_URL="http://linuxmint-troubleshooting-guide.readthedocs.io/en/latest/"
PRIVACY_POLICY_URL="https://www.linuxmint.com/"
VERSION_CODENAME=vera
UBUNTU_CODENAME=jammy
```

Install packages:

```
sudo apt install python3 python3-requests parted qemu-user-static debootstrap binfmt-support udev
```

Clone:

```
cd ~
git clone git@github.com:brucerry/BPI-Router-Images.git -b main
cd BPI-Router-Images
```

## Steps

1. Copy the U-boot and Linux packs to this workspace

2. Run script

```
./run.sh bpi-r3 noble
```

3. Flash eMMC

```
gunzip -c bpi-r3_noble_6.12.47-main_sdmmc.img.gz | dd bs=512 conv=notrunc,fsync of=/dev/mmcblk0
```