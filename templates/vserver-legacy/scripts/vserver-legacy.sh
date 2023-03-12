#!/bin/bash
#
# legacy vserver template
#

BASE="/etc/simplepkg/templates/vserver-legacy/vserver-legacy.s/"
DEVICES="$BASE/devices.tar.gz"
GPGKEY="$BASE/GPG-KEY"
SKEL="$BASE/skel.conf"

if [ -z "$2" ]; then
  echo "usage: `basename $0` <jail-root> <jail-name>"
  exit 1
elif [ ! -d "$1/$2" ]; then
  echo "folder $1/$2 does not exist"
  exit 1
fi

cp /etc/resolv.conf $1/$2/etc/
cp /etc/localtime $1/$2/etc/
echo /dev/hdv1 / ext2 defaults 1 1 > $1/$2/etc/fstab                                                           
echo /dev/hdv1 / ext2 rw 0 0 > $1/$2/etc/mtab                                                                  

echo "creating devices and dependencies"
if [ -f "$DEVICES" ]; then
  cd $1/$2/
  tar zxvf $DEVICES
  chroot $1/$2/ sbin/ldconfig
else
  echo error: device template $DEVICES not found
fi

if [ -f "$SKEL" ]; then
  echo "creating /etc/vservers/$2.conf"
  mkdir -p /etc/vservers
  cp $SKEL /etc/vservers/$2.conf
else
  echo error: config file template $SKEL not found
fi

if [ -f "$GPGKEY" ]; then
  echo "importing slack gpg pubkey"                                                                                  
  mkdir $1/$2/root/.gnupg                                                                                        
  gpg --homedir $1/$2/root/.gnupg --import $GPGKEY
fi

echo "done; now edit /etc/vservers/$2.conf"
echo "then, set all desired iptables rules and start $server vserver"
echo "dont forget to change root's password with the command "vserver $2 exec passwd"" 
