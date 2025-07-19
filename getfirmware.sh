#!/bin/bash
localdir=firmware
folders="aeonsemi airoha mediatek"
git clone -n --depth=1 --filter=tree:0 \
  https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git \
  $localdir
cd $localdir
git fetch --depth=1
git reset --hard origin/main
git sparse-checkout set --no-cone $folders
git checkout
du -hs
cd ..
