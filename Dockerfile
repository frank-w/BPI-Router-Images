FROM debian

RUN apt-get update && apt-get install -y \
  qemu-user-static \
  debootstrap \
  binfmt-support \
  git \
  sudo \
  python3 \
  python3-requests \
  parted \
  dpkg

WORKDIR /build
