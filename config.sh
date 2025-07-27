#!/bin/bash

#r2: dev: 0 part: 1/2
#r64: dev: 1 part: 4/5 (maybe needs fix for root in uboot, boot is checked by checkgpt)
#r2pro: dev: 1 part: 2/3
#r3/r4: dev: 0 part: 5/6

LANG=C
ubootconfig=uEnv.txt

case "$board" in
	"bpi-r2")
		mmcdev=0
		mmcbootpart=1
		mmcrootpart=2
		arch="armhf"
		kernel="5.15" #6.0+ does not support internal wifi
		ubootconfigdir=/bananapi/$board/linux/
	;;
	"bpi-r64")
		mmcdev=1
		mmcbootpart=4
		mmcrootpart=5
		arch="arm64"
	;;
	"bpi-r2pro")
		mmcdev=0
		mmcbootpart=2
		mmcrootpart=3
		arch="arm64"
	;;
	"bpi-r3"|"bpi-r3mini"|"bpi-r4")
		mmcdev=0
		mmcbootpart=5
		mmcrootpart=6
		arch="arm64"
	;;
	*)
		echo "missing/unsupported board $1";exit
	;;
esac
