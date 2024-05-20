#!/bin/bash
#sudo apt-get install qemu-user-static debootstrap binfmt-support

#debian
distro_debian=(buster bullseye bookworm)
name=debian
#distro=bullseye
distro=bookworm

#ubuntu
distro_ubuntu=(focal jammy noble)
#name=ubuntu
#distro=jammy #22.04

#arch=armhf
arch=arm64
#arch=amd64
#arch=x86_64

ramdisksize=1G

#sudo apt install debootstrap qemu-user-static
function checkpkg(){
	echo "checking for needed packages..."
	for pkg in debootstrap qemu-arm-static qemu-aarch64-static; do
		which $pkg >/dev/null;
		if [[ $? -ne 0 ]];then
			echo "$pkg missing";
			exit 1;
		fi;
	done
}

checkpkg

if [[ -n "$1" ]];then
	echo "\$1:"$1
	if [[ "$1" =~ armhf|arm64 ]];then
		echo "setting arch"
		arch=$1
	fi
fi

if [[ -n "$2" ]];then
	echo "\$2:"$2

	isdebian=$(echo ${distro_debian[@]} | grep -o "$2" | wc -w)
	isubuntu=$(echo ${distro_ubuntu[@]} | grep -o "$2" | wc -w)

	echo "isdebian:$isdebian,isubuntu:$isubuntu"
	if [[ $isdebian -ne 0 ]] || [[ $isubuntu -ne 0 ]];then
		echo "setting distro"
		distro=$2
		if [[ $isubuntu -ne 0 ]];then
			name="ubuntu"
		fi
	else
		echo "invalid distro $2"
		exit 1
	fi
fi

echo "create chroot '${name} ${distro}' for ${arch}"

#set -x
targetdir=$(pwd)/${name}_${distro}_${arch}
content=$(ls -A $targetdir 2>/dev/null)

if [[ -e $targetdir ]] && [[ "$content" ]]; then echo "$targetdir already exists - aborting";exit;fi

mkdir -p $targetdir
sudo chown root:root $targetdir

if [[ "$ramdisksize" != "" ]];
then
	mount | grep '\s'$targetdir'\s' &>/dev/null #$?=0 found;1 not found
	if [[ $? -ne 0 ]];then
		echo "mounting tmpfs for building..."
		sudo mount -t tmpfs -o size=$ramdisksize none $targetdir
	fi
fi

#mount | grep 'proc\|sys'
sudo debootstrap --arch=$arch --foreign $distro $targetdir
case "$arch" in
	"armhf")
		sudo cp /usr/bin/qemu-arm-static $targetdir/usr/bin/
	;;
	"arm64")
	#for r64 use
		sudo cp /usr/bin/qemu-aarch64-static $targetdir/usr/bin/
	;;
	"amd64")
		;;
	*) echo "unsupported arch $arch";;
esac
sudo cp /etc/resolv.conf $targetdir/etc
LANG=C

#sudo mount -t proc none $targetdir/proc/
#sudo mount -t sysfs sys $targetdir/sys/
#sudo mount -o bind /dev $targetdir/dev/
sudo chroot $targetdir /debootstrap/debootstrap --second-stage
ret=$?
if [[ $ret -ne 0 ]];then
	#sudo umount $targetdir/proc/
	#sudo umount $targetdir/sys/
	#sudo rm -rf $targetdir/*
	exit $ret;
fi

echo 'root:bananapi' | sudo chroot $targetdir /usr/sbin/chpasswd

langcode=de
if [[ "$name" == "debian" ]];then
trees="main contrib non-free non-free-firmware"
if [[ "$distro" =~ bookworm ]];then trees="$trees non-free-firmware"; fi
sudo chroot $targetdir tee "/etc/apt/sources.list" > /dev/null <<EOF
deb http://ftp.$langcode.debian.org/debian $distro $trees
deb-src http://ftp.$langcode.debian.org/debian $distro $trees
deb http://ftp.$langcode.debian.org/debian $distro-updates $trees
deb-src http://ftp.$langcode.debian.org/debian $distro-updates $trees
deb http://security.debian.org/debian-security ${distro}-security $trees
deb-src http://security.debian.org/debian-security ${distro}-security $trees
EOF
else
trees="main universe restricted multiverse"
sudo chroot $targetdir tee "/etc/apt/sources.list" > /dev/null <<EOF
deb http://ports.ubuntu.com/ubuntu-ports/ $distro $trees
deb-src http://ports.ubuntu.com/ubuntu-ports/ $distro $trees
deb http://ports.ubuntu.com/ubuntu-ports/ $distro-security $trees
deb-src http://ports.ubuntu.com/ubuntu-ports/ $distro-security $trees
deb http://ports.ubuntu.com/ubuntu-ports/ $distro-updates $trees
deb-src http://ports.ubuntu.com/ubuntu-ports/ $distro-updates $trees
deb http://ports.ubuntu.com/ubuntu-ports/ $distro-backports $trees
deb-src http://ports.ubuntu.com/ubuntu-ports/ $distro-backports $trees
EOF
fi
#sudo chroot $targetdir cat "/etc/apt/sources.list"

sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y openssh-server"
echo 'PermitRootLogin=yes'| sudo tee -a $targetdir/etc/ssh/sshd_config

echo 'bpi'| sudo tee $targetdir/etc/hostname

(
cd $targetdir
sudo tar -czf ../${distro}_${arch}.tar.gz .
)

if [[ "$ramdisksize" != "" ]];
then
	echo "umounting tmpfs..."
	sudo umount $targetdir
else
	sudo rm -rf $targetdir/.
fi
