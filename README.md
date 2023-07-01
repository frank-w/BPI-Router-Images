# BPI-Router-Images

## examples:

```sh
./buildimg.sh bpi-r2 jammy
./buildimg.sh bpi-r3 bookworm
```

## how to write image

```sh
gunzip -c bpi-r3_sdmmc.img.gz | sudo dd bs=1M status=progress conv=notrunc,fsync of=/dev/sdX
```
