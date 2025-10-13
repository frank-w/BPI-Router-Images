#!/bin/bash

function usage {
    echo "Usage: $0 <model> <distro>"
    echo "Available models: bpi-r3 bpi-r4"
    echo "Available distro:"
    echo "    * Debian: buster bullseye bookworm trixie"
    echo "    * Ubuntu: focal jammy noble"
}

[ $# -ne 2 ] && usage && exit 1

model=$1
distro=$2

distro_debian=(buster bullseye bookworm trixie)
distro_ubuntu=(focal jammy noble)

for d in ${distro_debian[@]}; do
    [ $d == $distro ] && name="debian" && break
done

for d in ${distro_ubuntu[@]}; do
    [ $d == $distro ] && name="ubuntu" && break
done

[ -z "$name" ] && echo "Unsupported distro: $distro" && exit 1

case $model in
    bpi-r3) ;;
    bpi-r4) ;;
    *) echo "Unsupported model: $model" && usage && exit 1 ;;
esac

uboot=${model}_emmc.img.gz
kernel=${model}_6.17.0-main.tar.gz

[ ! -e $uboot ] && echo "File not found: $uboot" && exit 1
[ ! -e $kernel ] && echo "File not found: $kernel" && exit 1

time {
    sudo losetup -D
    sudo umount -l ${name}_${distro}_arm64
    sudo rm -rf ${name}_${distro}_arm64 ${distro}_arm64.tar.gz
    git restore .
    conffile=sourcefiles_${model}.conf
    rm -rf $conffile
    [ $model = "bpi-r4" ] && echo -e "replacehostapd=1\nreplaceiperf=1" >> $conffile
    echo "skipubootdownload=1" >> $conffile
    echo "skipkerneldownload=1" >> $conffile
    echo "imgfile=$uboot" >> $conffile
    echo "kernelfile=$kernel" >> $conffile
    echo "userpackages=\"ethtool iperf3 tcpdump vim git tig mtd-utils memtester file pciutils usbutils traceroute net-tools psmisc wget curl fdisk ack bridge-utils wpasupplicant isc-dhcp-client man tshark\"" >> $conffile
    ./buildimg.sh $model $distro
}
