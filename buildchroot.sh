#!/bin/bash
#sudo apt-get install qemu-user-static debootstrap binfmt-support

#debian
distro_debian=(buster bullseye bookworm trixie)
name=debian
distro=trixie

#ubuntu
distro_ubuntu=(focal jammy noble resolute)
#name=ubuntu
#distro=resolute #26.04

#arch=armhf
arch=arm64
#arch=amd64
#arch=x86_64

ramdisksize=1G

#sudo apt install debootstrap qemu-user-static
function checkpkg(){
	echo "checking for needed packages..."
	#fix for debian where /usr/sbin/ is not in path for normal users (correctly)
	export PATH=$PATH:/usr/sbin/
	for pkg in debootstrap qemu-arm qemu-aarch64; do
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
sudo cp /etc/resolv.conf $targetdir/etc
LANG=C

sudo mount --rbind /dev "$targetdir/dev"
sudo mount --make-rslave "$targetdir/dev"

sudo mount -t proc proc "$targetdir/proc"
sudo mount -t sysfs sys "$targetdir/sys"
sudo mount --rbind /run "$targetdir/run"
sudo mount --make-rslave "$targetdir/run"

. /etc/os-release

echo "$VERSION_ID $arch"

case "$arch" in
	"armhf")
		qemu=qemu-arm
		if [[ "$VERSION_ID" =~ ^(22\.04|24\.04)$ ]]; then
			echo "install armhf static qemu"
			sudo apt install -y qemu-user-static
			sudo cp /usr/bin/qemu-arm-static "$targetdir/usr/bin/qemu-arm-static"
		fi
	;;
	"arm64")
	#for R64/R3/R4 use
		qemu=qemu-aarch64
		if [[ "$VERSION_ID" =~ ^(22\.04|24\.04)$ ]]; then
			echo "install arm64 static qemu"
			sudo apt install -y qemu-user-static
			sudo cp /usr/bin/qemu-aarch64-static "$targetdir/usr/bin/qemu-aarch64-static"
		fi
	;;
	"amd64")
	;;
	*) echo "unsupported arch $arch";exit 1;;
esac

#sudo install -m755 "/usr/bin/$qemu" \
#    "$targetdir/usr/bin/$qemu"

sudo chroot $targetdir /debootstrap/debootstrap --second-stage

ret=$?
if [[ $ret -ne 0 ]];then
	sudo umount -R "$targetdir/dev"
	sudo umount "$targetdir/proc"
	sudo umount "$targetdir/sys"
	sudo umount -R "$targetdir/run"
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

sudo umount -R "$targetdir/dev"
sudo umount "$targetdir/proc"
sudo umount "$targetdir/sys"
sudo umount -R "$targetdir/run"

if [[ "$ramdisksize" != "" ]];
then
	echo "umounting tmpfs..."
	sudo umount $targetdir
else
	sudo rm -rf $targetdir/.
fi
