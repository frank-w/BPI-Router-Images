#!/bin/bash
#sudo apt-get install qemu-user-static debootstrap binfmt-support
#r2: dev: 0 part: 1/2
#r64: dev: 1 part: 4/5 (maybe needs fix for root in uboot, boot is checked by checkgpt)
#r2pro: dev: 1 part: 2/3
#r3: dev: 0 part: 5/6
board=$1
distro=$2 #buster|bullseye|jammy
kernel="6.1"
case "$board" in
	"bpi-r2")
		mmcdev=0
		mmcbootpart=1
		mmcrootpart=2
		arch="armhf"
		kernel="5.15" #6.0+ does not support internal wifi
	;;
	"bpi-r64")
		mmcdev=1
		mmcbootpart=4
		mmcrootpart=5
		arch="arm64"
	;;
	"bpi-r2pro")
		mmcdev=1
		mmcbootpart=2
		mmcrootpart=3
		arch="arm64"
	;;
	"bpi-r3")
		mmcdev=0
		mmcbootpart=5
		mmcrootpart=6
		arch="arm64"
	;;
	*)
		echo "missing/unsupported board $1";exit
	;;
esac

echo "create image for ${board} (${arch}) ${distro} ${kernel}"

python3 downloadfiles.py ${board} ${kernel}

. sourcefiles_${board}.conf
echo "image-file:"$imgfile
echo "kernel-file:"$kernelfile

./buildchroot.sh ${arch} ${distro}
ls -lh ${distro}_${arch}.tar.gz

echo "unpack imgfile...(not yet)"
gunzip $imgfile
echo "setting up imgfile to loopdev...(not yet)"
LDEV=`losetup -f`
sudo losetup ${LDEV} ${imgfile%.*} 1> /dev/null
echo "mounting loopdev...(not yet)"
sudo partprobe ${LDEV}
mkdir -p mnt/BPI-{B,R}OOT
sudo mount ${LDEV}p${mmcbootpart} mnt/BPI-BOOT
sudo mount ${LDEV}p${mmcrootpart} mnt/BPI-ROOT
echo "unpack rootfs to bpi-root loopdev...(not yet)"
sudo tar -xzf ${distro}_${arch}.tar.gz -C mnt/BPI-ROOT
echo "unpack kernel to bpi-boot loopdev...(not yet)"
sudo tar -xzf $kernelfile --strip-components=1 -C mnt/BPI-BOOT BPI-BOOT
echo "unpack kernel-modules to bpi-root loopdev...(not yet)"
sudo tar -xzf $kernelfile --strip-components=2 -C mnt/BPI-ROOT/lib/ BPI-ROOT/lib/

targetdir="mnt/BPI-ROOT"

sudo chroot $targetdir tee "/etc/fstab" > /dev/null <<EOF
# <file system>		<dir>	<type>	<options>		<dump>	<pass>
/dev/mmcblk${mmcdev}p${mmcbootpart}		/boot	vfat	errors=remount-ro	0	1
/dev/mmcblk${mmcdev}p${mmcrootpart}		/	ext4	defaults		0	0
EOF

#sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y openssh-server"

echo $board | sudo tee $targetdir/etc/hostname

sudo umount mnt/BPI-BOOT
sudo umount mnt/BPI-ROOT
sudo losetup -d ${LDEV}
gzip ${imgfile%.*}
