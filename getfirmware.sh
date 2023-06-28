#!/bin/bash
localdir=firmware
folders="mediatek"
git clone -n --depth=1 --filter=tree:0 \
  https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git \
  $localdir
cd $localdir
git sparse-checkout set --no-cone $folders
git checkout
du -hs
cd ..
