#!/bin/bash
#sudo apt-get install qemu-user-static debootstrap binfmt-support
#r2: dev: 0 part: 1/2
#r64: dev: 1 part: 4/5 (maybe needs fix for root in uboot, boot is checked by checkgpt)
#r2pro: dev: 1 part: 2/3
#r3: dev: 0 part: 5/6
board=$1
distro=$2
kernel="6.1"
case "$board" in
	"bpi-r2")
		mmcdev=0
		mmcbootpart=1
		mmcrootpart=2
		arch="armhf"
		kernel="5.15"
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

exit

targetdir="BPI-ROOT"

#extract rootfs from buildchroot to rootpart

#extract kernel to bootpart and modules to rootpart

sudo chroot $targetdir tee "/etc/fstab" > /dev/null <<EOF
# <file system>		<dir>	<type>	<options>		<dump>	<pass>
/dev/mmcblk${mmcdev}p${mmcbootpart}		/boot	vfat	errors=remount-ro	0	1
/dev/mmcblk${mmcdev}p${mmcrootpart}		/	ext4	defaults		0	0
EOF

#sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y openssh-server"

echo $board | sudo tee $targetdir/etc/hostname

#sudo tar -czf ${name}_${distro}_${arch}.tar.gz $targetdir
