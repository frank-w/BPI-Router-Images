#!/bin/bash
#sudo apt-get install qemu-user-static debootstrap binfmt-support
#r2: dev: 0 part: 1/2
#r64: dev: 1 part: 4/5 (maybe needs fix for root in uboot, boot is checked by checkgpt)
#r2pro: dev: 1 part: 2/3
#r3: dev: 0 part: 5/6
board=$1
distro=$2 #bookworm|noble
kernel="6.12"

source config.sh

if [[ ! "$distro" =~ bookworm|noble ]];
then
	echo "invalid distribution '$distro'";
	exit;
fi
if [[ -n "$3" ]] && [[ "$3" =~ ^[1-9]\.[0-9]+$ ]];then kernel=$3;fi

PACKAGE_Error=0
PACKAGES=$(dpkg -l | awk '{print $2}')
NEEDED_PKGS="python3 python3-requests parted qemu-user-static debootstrap binfmt-support"
echo "needed: $NEEDED_PKGS"
for package in $NEEDED_PKGS; do
	#TESTPKG=$(dpkg -l |grep "\s${package}")
	TESTPKG=$(echo "$PACKAGES" |grep "^${package}")
	if [[ -z "${TESTPKG}" ]];then echo "please install ${package}";PACKAGE_Error=1;fi
done
if [ ${PACKAGE_Error} == 1 ]; then exit 1; fi


LDEV=`sudo losetup -f`

function cleanup() {
	sudo umount mnt/BPI-BOOT
	sudo umount mnt/BPI-ROOT
	sudo losetup -d $1
}

trap ctrl_c INT
function ctrl_c() {
        echo "** Trapped CTRL-C ($LDEV)"
	cleanup $LDEV
	exit 1
}

echo "create image for ${board} (${arch}) ${distro} ${kernel}"

python3 downloadfiles.py ${board} ${kernel}

ls -lh sourcefiles_${board}.conf
if [[ $? -ne 0 ]];then echo "sourcefiles_$board.conf file missing"; exit 1; fi

. sourcefiles_${board}.conf
echo "image-file: "$imgfile
echo "kernel-file: "$kernelfile
if [[ ! -e ${distro}_${arch}.tar.gz ]];then
	./buildchroot.sh ${arch} ${distro}
else
	echo "packed rootfs already exists"
fi
ls -lh ${imgfile}
if [[ $? -ne 0 ]];then echo "bootloader file missing"; exit 1; fi
ls -lh ${distro}_${arch}.tar.gz
if [[ $? -ne 0 ]];then echo "rootfs file missing"; exit 1; fi

if [[ -z "${kernelfile}" ]];then
	kernel="nokernel"
else
	kernel=$(echo ${kernelfile}|sed -e 's/^.*_\(.*\).tar.gz/\1/')
fi
newimgfile=${board}_${distro}_${kernel}.img.gz

cp $imgfile $newimgfile
echo "unpack imgfile ($newimgfile)..."
gunzip $newimgfile
echo "setting up imgfile to loopdev..."
sudo losetup ${LDEV} ${newimgfile%.*} 1> /dev/null
if [[ $? -ne 0 ]];then echo "losetup ${LDEV} failed (${newimgfile%.*})"; exit 1; fi
echo "mounting loopdev..."
sudo partprobe ${LDEV}
if [[ $? -ne 0 ]];then echo "partprobe failed"; exit 1; fi
mkdir -p mnt/BPI-{B,R}OOT
sudo mount ${LDEV}p${mmcbootpart} mnt/BPI-BOOT
if [[ $? -ne 0 ]];then echo "mounting BPI-BOOT failed"; exit 1; fi
sudo mkdir -p mnt/BPI-BOOT/${ubootconfigdir}
sudo touch mnt/BPI-BOOT/${ubootconfigdir}/${ubootconfig}
sudo mount ${LDEV}p${mmcrootpart} mnt/BPI-ROOT
if [[ $? -ne 0 ]];then echo "mounting BPI-ROOT failed"; exit 1; fi
echo "unpack rootfs to bpi-root loopdev..."
sudo tar -xzf ${distro}_${arch}.tar.gz -C mnt/BPI-ROOT

if [[ -n "${kernelfile}" ]];then
	ls -lh ${kernelfile}
	if [[ $? -ne 0 ]];then echo "kernel file missing"; exit 1; fi
	echo "unpack kernel to bpi-boot loopdev..."
	sudo tar -xzf $kernelfile --strip-components=1 -C mnt/BPI-BOOT BPI-BOOT
	ls -lR mnt/BPI-BOOT
	echo "unpack kernel-modules to bpi-root loopdev..."
	sudo tar -xzf $kernelfile --strip-components=2 -C mnt/BPI-ROOT/lib/. BPI-ROOT/lib/
else
	echo "kernelfile is empty so it will be missing in resulting image..."
fi

if [[ "$board" == "bpi-r2pro" ]];then
	conffile=mnt/BPI-BOOT/extlinux/extlinux.conf
	#mkdir -p $(dirname ${conffile})
	imgname="Image.gz"
	dtbname="bpi-r2pro.dtb"
	ls -la $(dirname ${conffile})
	echo -e "menu title Select the boot mode\n#timeout 1/10s\nTIMEOUT 50\nDEFAULT linux" | sudo tee $conffile
	echo -e "LABEL linux\n	linux $imgname\n	fdt $dtbname\n"\
		"	append earlycon=uart8250,mmio32,0xfe660000 " \
		"console=ttyS2,1500000n8 root=/dev/mmcblk${mmcdev}p${mmcrootpart} rootwait rw " \
		"earlyprintk" | sudo tee -a $conffile
	cat ${conffile}
fi

echo "configure rootfs for ${board}..."

targetdir="mnt/BPI-ROOT"

sudo chroot $targetdir tee "/etc/fstab" > /dev/null <<EOF
# <file system>		<dir>	<type>	<options>		<dump>	<pass>
/dev/mmcblk${mmcdev}p${mmcbootpart}		/boot	vfat	errors=remount-ro	0	1
/dev/mmcblk${mmcdev}p${mmcrootpart}		/	ext4	defaults		0	0
EOF

echo $board | sudo tee $targetdir/etc/hostname

sudo chroot $targetdir bash -c "apt update; DEBIAN_FRONTEND=noninteractive apt upgrade -y; apt clean"

if [[ ${board} != "bpi-r2pro" ]];then
	sudo chroot $targetdir bash -c "apt install --no-install-recommends -y hostapd iw xz-utils"
fi

sudo chroot $targetdir bash -c "apt update; apt install --no-install-recommends -y nftables ${additional_pkgs}"

sudo cp -r conf/generic/* ${targetdir}/
if [[ -e conf/$board ]];then
	sudo rsync -av --partial --progress --exclude={'bin','lib','sbin'} conf/${board}/. ${targetdir}/

	#fix for copy dir over symlink (rejected by cp)
	for d in bin lib sbin;do
		if [[ -d conf/${board}/$d ]];then
			sudo cp -r conf/${board}/$d/* ${targetdir}/$d/
		fi
	done
fi
sudo chroot $targetdir bash -c "systemctl enable systemd-networkd"

function download_firmware()
{
	targetdir=$1
	shift 1 # Removes $1 from the parameter list

	fwdir=${targetdir}/lib/firmware/
	for f in $@;do
		src="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/$f";
		echo "$src => $fwdir/$f"
		sudo curl -L --silent --create-dirs --output $fwdir/$f $src
		ret=$?
		if [[ $ret -ne 0 ]];then return $ret;fi
	done
	return 0
}

#wifi related commands
if [[ ${board} != "bpi-r2pro" ]];then
	#fix for ConditionFileNotEmpty in existing hostapd service (can also point to ${DAEMON_CONF})
	if [[ ${board} == "bpi-r2" ]];then
		sudo mv $targetdir/etc/hostapd/hostapd_{wlan,ap}0.conf
		sudo sed -i 's/^#\(interface=ap0\)/\1/' $targetdir/etc/hostapd/hostapd_ap0.conf
		cat $targetdir/etc/hostapd/hostapd_ap0.conf
		sudo chroot $targetdir bash -c "ln -fs hostapd_ap0.conf /etc/hostapd/hostapd.conf"
		#unpack wmt-tools
		sudo tar -xzf $kernelfile --strip-components=1 -C $targetdir BPI-ROOT/{etc,usr,system}
		#disable ip setting and dnsmasq (done via systemd-config)
		sed -i "/hostapd started...set IP/,/service dnsmasq restart/d" $targetdir/usr/sbin/wifi.sh
		#add wifi.sh to rc.local (autostart)
		sed -i '/^exit/s/^/\/usr\/sbin\/wifi.sh &\n/' $targetdir/etc/rc.local
	else
		for a in hostapd iperf wpa_supplicant iproute2;
		do
			varname="replace${a}"
			if [[ -n "${!varname}" ]];then
				varname2="${a}file"
				#tar -tzf ${!varname2} #currently only show content
				echo "unpack $a to bpi-root loopdev..."
				if [[ "$a" =~ hostap|wpa_supplicant ]];then
					sudo tar -xzf ${!varname2} -C mnt/BPI-ROOT/usr/local/sbin/
				else
					sudo tar -xzf ${!varname2} -C mnt/BPI-ROOT/usr/local/
				fi
			fi
		done
		ls -lh mnt/BPI-ROOT/usr/local/{,s}bin/
		if [[  "$board" == "bpi-r4" ]]; then
			sudo rm $targetdir/etc/hostapd/hostapd_wlan*.conf
			sudo chroot $targetdir bash -c "ln -fs hostapd_2g4.conf /etc/hostapd/hostapd.conf"
		else
			sudo chroot $targetdir bash -c "ln -fs hostapd_wlan0.conf /etc/hostapd/hostapd.conf"
		fi
		ls -lh mnt/BPI-ROOT/etc/hostapd/
	fi
	#copy firmware
	if [[ ! -d firmware ]];
	then
		./getfirmware.sh
	fi
	echo "copy firmware files"
	sudo cp -r firmware/* ${targetdir}/lib/firmware/

	curl https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain/regulatory.db -o regulatory.db-git
	curl https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain/regulatory.db.p7s -o regulatory.db.p7s-git

	sudo cp -r regulatory.* ${targetdir}/lib/firmware/
	sudo chroot $targetdir bash -c "update-alternatives --install /lib/firmware/regulatory.db regulatory.db /lib/firmware/regulatory.db-git 200 --slave /lib/firmware/regulatory.db.p7s regulatory.db.p7s /lib/firmware/regulatory.db.p7s-git"
	sudo chroot $targetdir bash -c "update-alternatives --set regulatory.db /lib/firmware/regulatory.db-git"

	if [[ ${board} == "bpi-r64" ]];then
		echo "mt7615e" | sudo tee -a ${targetdir}/etc/modules
	fi

	if [[ ${board} == "bpi-r4" ]];then
		#remove lan0 from lanbr0
		sudo sed 's/lan0 //' ${targetdir}/etc/systemd/network/21-lanbr-bind.network
		#copy actual firmware files to image
		download_firmware $targetdir mediatek/mt7996/{mt7996_dsp,mt7996_eeprom_233,mt7996_rom_patch_233,mt7996_wa_233,mt7996_wm_233}.bin
		download_firmware $targetdir mediatek/mt7988/i2p5ge-phy-pmb.bin
		download_firmware $targetdir aeonsemi/as21x1x_fw.bin
		sudo ls -lRh $fwdir
		#changes for 2.5g phy and R4Pro variant
		echo "# is2g5=1" | sudo tee -a mnt/BPI-BOOT/${ubootconfigdir}/${ubootconfig}
		echo "# isr4pro=1" | sudo tee -a mnt/BPI-BOOT/${ubootconfigdir}/${ubootconfig}
		echo "# mtk-2p5ge" | sudo tee -a ${targetdir}/etc/modules
	fi
fi

#install userspecified packages
if [[ -n "$userpackages" ]]; then
	echo "installing user specified packages: $userpackages"
	sudo chroot $targetdir bash -c "DEBIAN_FRONTEND=noninteractive apt install -y $userpackages"
fi

#install/start resolved after all is done (resolving is broken in chroot after that)
sudo chroot $targetdir bash -c "apt install -y systemd-resolved;systemctl enable systemd-resolved"

cleanup ${LDEV}

echo "packing ${newimgfile}"
gzip ${newimgfile%.*}
md5sum ${newimgfile} > ${newimgfile}.md5
echo "install it this way:"
echo "gunzip -c ${newimgfile} | sudo dd bs=1M status=progress conv=notrunc,fsync of=/dev/sdX"

rm $imgfile
