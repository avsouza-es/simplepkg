#!/bin/sh
#
# /etc/rc.d/rc.S:  System initialization script.
#
# Mostly written by:  Patrick J. Volkerding, <volkerdi@slackware.com>
#

PATH=/sbin:/usr/sbin:/bin:/usr/bin

# Mount /proc right away:
/sbin/mount -v proc /proc -n -t proc

# If 'nohotplug' was given at boot, or rc.hotplug has been turned off
# (is not executable), then shut off hotplugging in the kernel now.
# Turning off hotplug is *not* recommended, and will break some things.
if [ -w /proc/sys/kernel/hotplug ]; then
  if grep -w nohotplug /proc/cmdline 1> /dev/null 2> /dev/null ; then
    echo "/dev/null" > /proc/sys/kernel/hotplug
  elif [ ! -x /etc/rc.d/rc.hotplug ]; then
    echo "/dev/null" > /proc/sys/kernel/hotplug
  fi
fi

# Start devfsd if necessary.  On newer kernels, udev should be used instead.
if [ -x /etc/rc.d/rc.devfsd ]; then
  /etc/rc.d/rc.devfsd start
fi

# Mount sysfs next, if the kernel supports it:
if [ -d /sys ]; then
  if cat /proc/filesystems | grep -w sysfs 1> /dev/null 2> /dev/null ; then
    if ! cat /proc/mounts | grep -w sysfs 1> /dev/null 2> /dev/null ; then
      /sbin/mount -v sysfs /sys -n -t sysfs
    fi
  fi
fi

# Initialize udev to manage /dev entries for 2.6.x kernels:
if [ -x /etc/rc.d/rc.udev ]; then
  if ! grep -w nohotplug /proc/cmdline 1> /dev/null 2> /dev/null ; then
    /etc/rc.d/rc.udev
  fi
fi

# Enable swapping:
/sbin/swapon -a

# Test to see if the root partition is read-only, like it ought to be.
READWRITE=no
if touch /fsrwtestfile 2>/dev/null; then
  rm -f /fsrwtestfile
  READWRITE=yes
else
  echo "Testing root filesystem status:  read-only filesystem"
fi

# See if a forced filesystem check was requested at shutdown:
if [ -r /etc/forcefsck ]; then
  FORCEFSCK="-f"
fi

# Check the root filesystem:
if [ ! $READWRITE = yes ]; then
  RETVAL=0
  if [ ! -r /etc/fastboot ]; then
    echo "Checking root filesystem:"
    /sbin/fsck $FORCEFSCK -C -a /
    RETVAL=$?
  fi
  # An error code of 2 or higher will require a reboot.
  if [ $RETVAL -ge 2 ]; then
    # An error code equal to or greater than 4 means that some errors
    # could not be corrected.  This requires manual attention, so we
    # offer a chance to try to fix the problem in single-user mode:
    if [ $RETVAL -ge 4 ]; then
      echo
      echo "***********************************************************"
      echo "*** An error occurred during the root filesystem check. ***"
      echo "*** You will now be given a chance to log into the      ***"
      echo "*** system in single-user mode to fix the problem.      ***"
      echo "***                                                     ***"
      echo "*** If you are using the ext2 filesystem, running       ***"
      echo "*** 'e2fsck -v -y <partition>' might help.              ***"
      echo "***********************************************************"
      echo
      echo "Once you exit the single-user shell, the system will reboot."
      echo
      PS1="(Repair filesystem) \#"; export PS1
      sulogin
    else # With an error code of 2 or 3, reboot the machine automatically:
      echo
      echo "***********************************"
      echo "*** The filesystem was changed. ***"
      echo "*** The system will now reboot. ***"
      echo "***********************************"
      echo
    fi
    echo "Unmounting file systems."
    /sbin/umount -a -r
    /sbin/mount -n -o remount,ro /
    echo "Rebooting system."
    sleep 2
    reboot -f
  fi
  # Remount the root filesystem in read-write mode
  echo "Remounting root device with read-write enabled."
  /sbin/mount -w -v -n -o remount /
  if [ $? -gt 0 ] ; then
    echo
    echo "Attempt to remount root device as read-write failed!  This is going to"
    echo "cause serious problems."
    echo 
    echo "If you're using the UMSDOS filesystem, you **MUST** mount the root partition"
    echo "read-write!  You can make sure the root filesystem is getting mounted "
    echo "read-write with the 'rw' flag to Loadlin:"
    echo
    echo "loadlin vmlinuz root=/dev/hda1 rw   (replace /dev/hda1 with your root device)"
    echo
    echo "Normal bootdisks can be made to mount a system read-write with the rdev command:"
    echo
    echo "rdev -R /dev/fd0 0"
    echo
    echo "You can also get into your system by using a boot disk with a command like this"
    echo "on the LILO prompt line:  (change the root partition name as needed)"
    echo 
    echo "LILO: mount root=/dev/hda1 rw"
    echo
    echo "Please press ENTER to continue, then reboot and use one of the above methods to"
    echo -n "get into your machine and start looking for the problem. " 
    read junk; 
  fi
else
  echo "Testing root filesystem status:  read-write filesystem"
  if cat /etc/fstab | grep ' / ' | grep umsdos 1> /dev/null 2> /dev/null ; then
    ROOTTYPE="umsdos"
  fi
  if [ ! "$ROOTTYPE" = "umsdos" ]; then # no warn for UMSDOS
    echo
    echo "*** ERROR: Root partition has already been mounted read-write. Cannot check!"
    echo
    echo "For filesystem checking to work properly, your system must initially mount"
    echo "the root partition as read only. Please modify your kernel with 'rdev' so that"
    echo "it does this. If you're booting with LILO, add a line:"
    echo
    echo "   read-only"
    echo
    echo "to the Linux section in your /etc/lilo.conf and type 'lilo' to reinstall it."
    echo
    echo "If you boot from a kernel on a floppy disk, put it in the drive and type:"
    echo "   rdev -R /dev/fd0 1"
    echo
    echo "If you boot from a bootdisk, or with Loadlin, you can add the 'ro' flag."
    echo
    echo "This will fix the problem *AND* eliminate this annoying message. :^)"
    echo
    echo -n "Press ENTER to continue. "
    read junk;
  fi
fi # Done checking root filesystem

# Any /etc/mtab that exists here is old, so we delete it to start over:
/bin/rm -f /etc/mtab*
# Remounting the / partition will initialize the new /etc/mtab:
/sbin/mount -w -o remount /

# Fix /etc/mtab to list sys and proc if they were not yet entered in
# /etc/mtab because / was still mounted read-only:
if [ -d /proc/sys ]; then
  /sbin/mount -f proc /proc -t proc
fi
if [ -d /sys/bus ]; then
  /sbin/mount -f sysfs /sys -t sysfs
fi

# Set the system time from the hardware clock using hwclock --hctosys.
if [ -x /sbin/hwclock ]; then
  if grep "^UTC" /etc/hardwareclock 1> /dev/null 2> /dev/null ; then
    echo "Setting system time from the hardware clock (UTC)."
    /sbin/hwclock --utc --hctosys
  else
    echo "Setting system time from the hardware clock (localtime)."
    /sbin/hwclock --localtime --hctosys
  fi
fi

# Configure ISA Plug-and-Play devices:
if [ -r /etc/isapnp.conf ]; then
  if [ -x /sbin/isapnp ]; then
    /sbin/isapnp /etc/isapnp.conf
  fi
fi

# This loads any kernel modules that are needed.  These might be required to
# use your ethernet card, sound card, or other optional hardware.
if [ -x /etc/rc.d/rc.modules -a -r /proc/modules ]; then
  . /etc/rc.d/rc.modules
fi

# Configure runtime kernel parameters:
if [ -x /sbin/sysctl -a -r /etc/sysctl.conf ]; then
  /sbin/sysctl -e -p /etc/sysctl.conf
fi

# Initialize the Logical Volume Manager.
# This won't start unless we find /etc/lvmtab (LVM1) or 
# /etc/lvm/backup/ (LVM2).  This is created by /sbin/vgscan, so to
# use LVM you must run /sbin/vgscan yourself the first time (and
# create some VGs and LVs).
if [ -r /etc/lvmtab -o -d /etc/lvm/backup ]; then
  echo "Initializing LVM (Logical Volume Manager):"
  # Check for device-mapper support.
  if ! cat /proc/devices | grep -w device-mapper 1> /dev/null 2> /dev/null ; then
    # If device-mapper exists as a module, try to load it.
    if [ -r /lib/modules/$(cat /proc/sys/kernel/osrelease)/kernel/drivers/md/dm-mod.ko ]; then
      insmod /lib/modules/$(cat /proc/sys/kernel/osrelease)/kernel/drivers/md/dm-mod.ko
    fi
  fi
  # Scan for new volume groups:
  /sbin/vgscan 2> /dev/null
  if [ $? = 0 ]; then
    # This needs a moment to register.
    sleep 10
    # Make volume groups available to the kernel.
    # This should also make logical volumes available.
    /sbin/vgchange -ay
    # Enable swapping again in case any LVs are used for swap.  Ignore previous error.  :-)
    /sbin/swapon -a
  fi
fi

# Check all the non-root filesystems:
if [ ! -r /etc/fastboot ]; then
  echo "Checking non-root filesystems:"
  /sbin/fsck $FORCEFSCK -C -R -A -a
fi

# mount non-root file systems in fstab (but not NFS or SMB 
# because TCP/IP is not yet configured, and not proc because
# that has already been mounted):
/sbin/mount -a -v -t nonfs,nosmbfs,noproc

# Clean up some temporary files:
( cd /var/log/setup/tmp && rm -rf * )
/bin/rm -f /var/run/utmp /var/run/*pid /etc/nologin /var/run/lpd* \
  /var/run/ppp* /etc/dhcpc/*.pid /etc/forcefsck /etc/fastboot

# Attempt to umount and remove any leftover /initrd:
if [ -d /initrd ]; then
  /sbin/umount /initrd 2> /dev/null
  rmdir /initrd 2> /dev/null
  blockdev --flushbufs /dev/ram0 2> /dev/null
fi

# Create a fresh utmp file:
touch /var/run/utmp
chown root.utmp /var/run/utmp
chmod 664 /var/run/utmp

if [ "$ROOTTYPE" = "umsdos" ]; then # we need to update any files added in DOS:
  echo "Synchronizing UMSDOS directory structure:"
  echo "  /sbin/umssync -r99 -v- /"
  /sbin/umssync -r99 -v- /
fi

# Setup the /etc/motd to reflect the current kernel level:
# THIS WIPES ANY CHANGES YOU MAKE TO /ETC/MOTD WITH EACH BOOT.
# COMMENT THIS OUT IF YOU WANT TO MAKE A CUSTOM VERSION.
echo "$(/bin/uname -sr)." > /etc/motd

# If there are SystemV init scripts for this runlevel, run them.
if [ -x /etc/rc.d/rc.sysvinit ]; then
  . /etc/rc.d/rc.sysvinit
fi

# Run serial port setup script:
# (CAREFUL! This can make some systems hang if the rc.serial script isn't
# set up correctly. If this happens, you may have to edit the file from a
# boot disk)
#
# . /etc/rc.d/rc.serial

# Carry an entropy pool between reboots to improve randomness.
if [ -f /etc/random-seed ]; then
  echo "Using /etc/random-seed to initialize /dev/urandom."
  cat /etc/random-seed > /dev/urandom
fi
# Use the pool size from /proc, or 512 bytes:
if [ -r /proc/sys/kernel/random/poolsize ]; then
  dd if=/dev/urandom of=/etc/random-seed count=1 bs=$(cat /proc/sys/kernel/random/poolsize) 2> /dev/null
else
  dd if=/dev/urandom of=/etc/random-seed count=1 bs=512 2> /dev/null
fi
chmod 600 /etc/random-seed

