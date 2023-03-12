#!/bin/bash

if [ -z "$2" ]; then
  echo "usage: `basename $0` <jail-root> <jail-name>"
  exit 1
elif [ ! -d "$1/$2" ]; then
  echo "folder $1/$2 does not exist"
  exit 1
fi

echo running post-installation script for $1/$2 jail...

# copia de arquivos
cp -p /etc/passwd $1/$2/etc/
cp -p /etc/group $1/$2/etc/
cp /etc/localtime $1/$2/etc/

# pos-instalacao
mount -t proc proc $1/$2/proc
chroot $1/$2 /sbin/ldconfig
cd $1/$2 && exec ./var/log/scripts/glibc-zoneinfo-*
umount $1/$2/proc
