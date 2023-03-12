#!/bin/bash
#
# vserver template script
#

BASE="/etc/simplepkg/templates/vserver/vserver.s"
DEVICES="$BASE/devices.tar.gz"
GPGKEY="$BASE/GPG-KEY"

if [ -z "$2" ]; then
  echo "usage: `basename $0` <jail-root> <jail-name>"
  exit 1
elif [ ! -d "$1/$2" ]; then
  echo "folder $1/$2 does not exist"
  exit 1
fi

echo "creating /etc/vservers/$2..."
mv $1/$2 $1/$2.old
vserver $2 build -m skeleton --force &> /dev/null
result="$?"
rm -rf $1/$2 && mv $1/$2.old $1/$2 

if [ "$result" != "0" ]; then
  mkdir -p /etc/vservers/$2/apps/init
fi

echo sysv > /etc/vservers/$2/apps/init/style
echo 3 > /etc/vservers/$2/apps/init/runlevel.start
echo 6 > /etc/vservers/$2/apps/init/runlevel.stop

cp /etc/resolv.conf $1/$2/etc/
cp /etc/localtime $1/$2/etc/
echo /dev/hdv1 / ext2 defaults 1 1 > $1/$2/etc/fstab                                                           
echo /dev/hdv1 / ext2 rw 0 0 > $1/$2/etc/mtab                                                                  

echo "creating devices and dependencies..."
if [ -f "$DEVICES" ]; then
  cd $1/$2/
  tar zxvf $DEVICES
  chroot $1/$2/ sbin/ldconfig
else
  echo error: device template $DEVICES not found
fi

if [ -f "$GPGKEY" ]; then
  echo "importing slack gpg pubkey"                                                                                  
  mkdir $1/$2/root/.gnupg                                                                                        
  gpg --homedir $1/$2/root/.gnupg --import $GPGKEY
fi

# todo: add rebootmgr
echo "done; now config your vserver at /etc/vservers/$2"
echo "then, set all desired iptables rules and other stuff and then start $server vserver"
echo "dont forget to change root's password with the command "vserver $2 exec passwd"" 
