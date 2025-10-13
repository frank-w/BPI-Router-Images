## Prerequisite

1. Build U-boot https://github.com/brucerry/BPI-Router-Uboot
    - bpi-r4_emmc.img.gz

2. Build Linux https://github.com/brucerry/BPI-Router-Linux
    - bpi-r4_6.17.0-main.tar.gz
    
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
./run.sh bpi-r4 noble
```

3. Flash eMMC

```
echo 0 > /sys/block/mmcblk0boot0/force_ro
dd if=bpi-r4_emmc_bl2.img of=/dev/mmcblk0boot0
gunzip -c bpi-r4_noble_6.17.0-main_sdmmc.img.gz | dd bs=512 conv=notrunc,fsync of=/dev/mmcblk0
mmc bootpart enable 1 1 /dev/mmcblk0
```