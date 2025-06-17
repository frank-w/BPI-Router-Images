#!/bin/bash
imgfile=$1
action=$2
if [[ ! -e "$imgfile" ]];then echo "no filename given";exit;fi
board=$(echo $imgfile | sed -e 's/_.*$//')

source config.sh

function mount_image()
{
	newimgfile=$1
	LDEV=$(sudo losetup -f)
	echo "unpack imgfile ($newimgfile)..."
	gunzip $newimgfile
	echo "setting up imgfile to loopdev..."
	sudo losetup ${LDEV} ${newimgfile%.*} 1> /dev/null
	if [[ $? -ne 0 ]];then echo "losetup ${LDEV} failed (${newimgfile%.*})"; exit 1; fi
	echo "mounting loopdev..."
	sudo partprobe ${LDEV}
	if [[ $? -ne 0 ]];then echo "partprobe failed"; exit 1; fi
	mkdir -p mnt/BPI-{B,R}OOT
	echo "mount ${LDEV}p${mmcbootpart} => mnt/BPI-BOOT"
	sudo mount ${LDEV}p${mmcbootpart} mnt/BPI-BOOT
	if [[ $? -ne 0 ]];then echo "mounting BPI-BOOT failed"; exit 1; fi
	echo "mount ${LDEV}p${mmcrootpart} => mnt/BPI-ROOT"
	sudo mount ${LDEV}p${mmcrootpart} mnt/BPI-ROOT
	if [[ $? -ne 0 ]];then echo "mounting BPI-ROOT failed"; exit 1; fi
}

function umount_image()
{
	imgfile=$1
	LDEV=$(sudo losetup -l | grep $imgfile | awk '{print $1}')
	sudo umount ${LDEV}p*
	sudo losetup -d $LDEV
}

case $action in
	"mount")
		echo "mounting image $imgfile ..."
		mount_image $imgfile
	;;
	"umount")
		echo "umounting image $imgfile ..."
		umount_image $imgfile
	;;
	*)
		echo "invalid action"
		exit 1
	;;
esac
