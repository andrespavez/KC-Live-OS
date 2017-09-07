#!/bin/bash -x
#
# Creating the KC DVD ISO based on a Live CD.
# Changes, remove, recompress it into a SquashFS image, add, hash, etc
#
# To-do:
# Define the path for the working directory and also for the ISO. Maybe $1 and $2
# Write the warning and consideration to run the scrip - need to be run in a Linux machine, recommendation a minimal virtual machine
# Verify the signature with PGP
# Sign this scrip
# Any way to check the scrip version?
# Verify the final hash of the ISO
# Add a clean up
# wget .iso
# wget the custom KM-SW?, and all the other files?
# check if automount is disable
# make for any unix/linux distribution
# Verify the mksqushfd version
# Instead of moving, copy and deleting the squashfs.img just unsquashfs from the original directory, them replace the old for the new.
# Use only one source of time and use a tool to change it
#
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# Be sure to verify that you will have sufficient space before running the script.
# This may require, for example, over 12.0 GiB of free space for full live system


ROOT_UID=0	# Only users with $UID 0 have root privileges
DEBIAN_VERSION="debian-live-9.1.0-amd64-xfce.iso"	# Current Debian XFCE live version
DEBIAN_HASH="54a422b740c3c3944931d547f38478bbc62843988448177da1586d65d02fc49f  -" # the " -" is necessary for the comparative unless if "sed" is used SHA-256
KS_DVD=0	# SHA256 ()
M_ISO=live-iso	# Mount folder for the iso
DATE=20171011 #`date +%Y%m%d` # Current date
M_WD=KC-$DATE	# Working directory to create the ISO
SERIAL="ICANN-DNSSEC-KC-$DATE" # Serial
M_SMNT=squashmnt	# Mount folder for mounting squash file system
M_SFS=squashfs		# Mount folder for squash file system
M_RFS=rootfs		# Mount folder for root file system
B_TIME=$(date --date="$DATE" +%s)  # Time for squashfs EPOCH with UTC and 00:00:00
M_TIME="${DATE}00000000" # Time YYYYMMDDhhmmsscc to control the timestamps of the filesystem superblocks and other global components of the ISO file system
F_TIME="${DATE}}0000.00"  # Ext3 Filesystem time

# Confirmation source: http://stackoverflow.com/questions/1885525/how-do-i-prompt-a-user-for-confirmation-in-bash-script
echo "Warning this can be dangerous. It will use chroot command to remove packages, changes configurations, etc. So, if something is going wrong can change from your host system rather than from the Live CD image. You need to be root and execute under your own responsibility"
read -p "Are you sure to continue [y/N]? " -n 1 -r
echo    # Move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

# Run as root source: http://www.iitk.ac.in/LDP/LDP/abs/html/abs-guide.html#EX2
if [ "$UID" -ne "$ROOT_UID" ]
then
  echo "Must be root to run this script."
  exit 1
fi

# Checking squashfs-tools source: http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
# ADD check VERSION
command -v mksquashfs >/dev/null 2>&1 || { echo >&2 "Please install (with XZ support) the last squashfs-tools direct form GitHub https://github.com/squashfs-tools/squashfs-tools.git"; exit 1; }

#unsquashfs version 4.3 (2014/05/12)
#mksquashfs version 4.3-git (2014/09/12)

# Checking rsync
command -v rsync >/dev/null 2>&1 || { echo >&2 "Please install rsync"; exit 1; }

# Checking xorriso
command -v xorriso >/dev/null 2>&1 || { echo >&2 "Please install xorriso"; exit 1; }

#xorriso version   :  1.4.6
#Version timestamp :  2016.09.16.133001
#Build timestamp   :  -none-given-
#libisofs   in use :  1.4.6  (min. 1.4.6)
#libburn    in use :  1.4.6  (min. 1.4.6)
#libburn OS adapter:  internal GNU/Linux SG_IO adapter sg-linux
#libisoburn in use :  1.4.6  (min. 1.4.6)

# Checking the ISO HASH
echo "Calculating the ISO SHA-256 HASH of the $DEBIAN_VERSION"
iso_hash=$(sha256sum < "$DEBIAN_VERSION") # | sed 's/\(.*\) .*/\1/') # in the same directory as the script
echo "SHA-256 HASH: $iso_hash"
echo "Debian  HASH: $DEBIAN_HASH"
if [ "$iso_hash" != "$DEBIAN_HASH" ]
then
  echo "ERROR: SHA-256 hashes mismatched, try to download again the $DEBIAN_VERSION"
  exit 1
else
  echo "SHA-256 HASH of the $DEBIAN_VERSION is OK"
fi

# Using xorriso with osirrox a more efficient way to copy the iso content
## Mounting the Live ISO
#mkdir $M_ISO
#mount -o loop $DEBIAN_VERSION $M_ISO
#
# Creating the work directory
mkdir $M_WD
#
## Coping the entire ISO
#rsync -ar --inplace --progress $M_ISO/ $M_WD
###cp -rdav $M_ISO/* $M_WD/ #rsync is better with progress information
#
## umount the ISO it not longer needed
#umount $M_ISO
#rmdir $M_ISO

xorriso -osirrox on -indev $DEBIAN_VERSION -extract / $M_WD

# Changing isolinux.cfg
# Reducing the boot menu time
sed -i 's/^timeout .*$/timeout 100/' $M_WD/isolinux/isolinux.cfg

# Adding kerner options
sed -i '7s/\bcomponents\b/& locales=en_US.UTF-8 net.ifnames=0 selinux=0 nosound nobluetooth/' $M_WD/isolinux/menu.cfg

# Updating also grub.cfg
sed -i '27s/\bcomponents\b/& locales=en_US.UTF-8 net.ifnames=0 selinux=0 nosound nobluetooth/' $M_WD/boot/grub/grub.cfg

# Moving the squashfs.img to current directory
mv $M_WD/live/filesystem.squashfs .

# Using unsquashfs a more efficient way to copy the file system
# Mounting the squashfs.img
#mkdir $M_SMNT
#mount -o loop -t squashfs squashfs.img $M_SMNT
#
# Copy squashfs file system
mkdir $M_SFS
#rsync -ar --inplace --progress $M_SMNT/ $M_SFS
#
# Umount the squashfs.img it not longer needed
#umount $M_SMNT
#rmdir $M_SMNT

unsquashfs -f -d $M_SFS filesystem.squashfs

# Removing the squashfs.img
rm -f filesystem.squashfs

exit 1
# Mounting the root root file system
mkdir $M_RFS
mount $M_SFS/LiveOS/rootfs.img $M_RFS

# Edit section
# Disabling selinux
sed -i 7s/enforcing/disabled/ $M_RFS/etc/selinux/config

# Entering to chroot environment
# chroot $M_RFS

# Remove unnecessary packages
chroot $M_RFS dnf -y remove firefox libreoffice-core cheese evolution gnome-contacts gnome-maps rhythmbox shotwell gnome-weather > /dev/null 2>&1
# dnf add a timestamp inside of the RPM database making not posible to create a reproducible build

# Disabling firewall
chroot $M_RFS systemctl disable firewalld > /dev/null 2>&1
chroot $M_RFS systemctl mask firewalld > /dev/null 2>&1
#rm -f $M_RFS/etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service
#rm -f $M_RFS/etc/systemd/system/multi-user.target.wants/firewalld.service
#ln -s /dev/null $M_RFS/etc/systemd/system/firewalld.service

# Disabling more services


# Changing time zone
chroot $M_RFS ln -fs /usr/share/zoneinfo/UTC /etc/localtime > /dev/null 2>&1
#ln -fs /usr/share/zoneinfo/UTC $M_RFS/etc/localtime

# Setting network



echo -e "192.168.0.2 \t hsm" >> $M_RFS/etc/hosts

# AEP Software
install -m 755 -d $M_RFS/opt/Keyper
install -m 755 -d $M_RFS/opt/Keyper/bin
install -m 755 -d $M_RFS/opt/Keyper/PKCS11Provider
install -m 755 -d $M_RFS/opt/Keyper/docs
install -m 555 ./aep/bin/*              $M_RFS/opt/Keyper/bin
install -m 444 ./aep/PKCS11Provider/*   $M_RFS/opt/Keyper/PKCS11Provider
install -m 444 ./aep/docs/*             $M_RFS/opt/Keyper/docs

# ICANN Software & Scripts
install -m 755 -d $M_RFS/opt/icann
install -m 755 -d $M_RFS/opt/icann/bin
install -m 755 -d $M_RFS/opt/icann/dist
install -m 555 ./icann/bin/* $M_RFS/opt/icann/bin
install -m 555 ./icann/dist/* $M_RFS/opt/icann/dist

# DNSSEC Configurations Files
install -m 755 -d $M_RFS/opt/dnssec
install -m 444 ./dnssec/fixenv      $M_RFS/opt/dnssec
install -m 444 ./dnssec/machine     $M_RFS/opt/dnssec
install -m 444 ./dnssec/*.hsmconfig $M_RFS/opt/dnssec

# Profile
# File created as ROOT
echo "export PATH=.:/opt/icann/bin:/opt/Keyper/bin:\$PATH" >> $M_RFS/etc/profile.d/kc.sh

# Serial
# File created as ROOT
echo "Serial: $SERIAL"  >>  $M_RFS/etc/SERIAL

# ADD MORE


# Seting filesystem timestamp
for file in $(find "$M_RFS" -mtime 0)
do
	touch -a -m -h -t $F_TIME $file
done

# Umount the root file system
umount $M_RFS
rmdir $M_RFS

# Creating the new squashfs, may want to use XZ compression
mksquashfs $M_SFS/ squashfs.img -noappend -comp xz -mkfs-fixed-time $B_TIME -content-fixed-time $B_TIME

# Carefully removing the squash file system
rm -rf $M_SFS

# Moving the squashfs.img to working directory
mv squashfs.img $M_WD/LiveOS/

# Setting permissions for squashfs.img
chmod 644 $M_WD/LiveOS/squashfs.img

# Change the timestamp for the modified files
for files in $(find "$M_WD" -mtime 0)
do
	touch -a -m -h -t $F_TIME $files
done

## Creating the iso
xorriso -as mkisofs -joliet -full-iso9660-filenames -rational-rock \
	-hide-rr-moved -volid ${M_WD/-/_} -output $M_WD.iso \
	-eltorito-boot isolinux/isolinux.bin -eltorito-catalog isolinux/boot.cat \
	-no-emul-boot -boot-info-table -boot-load-size 4 \
	modification-date=$M_TIME \
	$M_WD

## Carefully removing working directory
rm -rf $M_WD

# Checking the new iso HASH

# END
