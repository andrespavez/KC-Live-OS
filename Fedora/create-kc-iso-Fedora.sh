#!/bin/bash -x
#
# Creating the KC DVD ISO based on a Live CD.
# Changes, remove, recompress it into a SquashFS image, add, hash, etc 
#
# To-do:
# Define the path for the working directory and also for the ISO. Maybe $1 and $2 
# Write the warning and consideration to run the scrip - need to be run in a Linux machine, recommendation a minimal virtual machine
# Verify the signature with Fedora PGP
# Sign this scrip
# Any way to check the scrip version?
# Verify the final hash of the ISO
# Add a clean up
# wget fedora.iso
# wget the custom KM-SW?, and all the other files?
# check if automount is disable
# make for any unix/linux distribution
# Verify the mksqushfd version 
# Instead of moving, copy and deleting the squashfs.img just unsquashfs from the original directory, them replace the old for the new.
#
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

# Be sure to verify that you will have sufficient space before running the script.
# This may require, for example, over 12.0 GiB of free space for Fedora 25 Workstation Live


ROOT_UID=0	# Only users with $UID 0 have root privileges
FEDORA_VERSION="Fedora-Workstation-Live-x86_64-25-1.3.iso"	# Current fedora live version
FEDORA_HASH="818017f42a2741cfaf20e94aecf6a63d1b995abfdaff5917df7218d0d89976a7  -" # the " -" is necessary for the comparative unless if "sed" is used SHA-256 of (Fedora-Workstation-Live-x86_64-25-1.3.iso) 
KS_DVD=0	# SHA256 ()
M_ISO=live-iso	# Mount folder for the iso
M_WD=KC-2017XXXX	# Working directory to create the ISO
M_SMNT=squashmnt	# Mount folder for mounting squash file system
M_SFS=squashfs		# Mount folder for squash file system
M_RFS=rootfs		# Mount folder for root file system
B_TIME=1493298000	# Time for squashfs https://www.epochconverter.com/ Human time (GMT): Thu, 27 Apr 2017 13:00:00 GMT

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

# Checking rsync
command -v rsync >/dev/null 2>&1 || { echo >&2 "Please install rsync"; exit 1; }

# Checking xorriso
command -v xorriso >/dev/null 2>&1 || { echo >&2 "Please install xorriso"; exit 1; }

# Checking the ISO HASH
echo "Calculating the ISO SHA-256 HASH of the $FEDORA_VERSION"
iso_hash=$(sha256sum < "$FEDORA_VERSION") # | sed 's/\(.*\) .*/\1/') # in the same directory as the script
echo "SHA-256 HASH: $iso_hash"
echo "Fedora  HASH: $FEDORA_HASH"
if [ "$iso_hash" != "$FEDORA_HASH" ]
then
  echo "ERROR: SHA-256 hashes mismatched, try to download again the $FEDORA_VERSION"
  exit 1
else
  echo "SHA-256 HASH of the $FEDORA_VERSION is OK"
fi

# Using xorriso with osirrox a more efficient way to copy the iso content
## Mounting the Fedora Live ISO
#mkdir $M_ISO
#mount -o loop $FEDORA_VERSION $M_ISO
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

xorriso -osirrox on -indev $FEDORA_VERSION -extract / $M_WD

# Changing isolinux.cfg
# Reducing the boot menu time
sed -i 2s/6/1/ $M_WD/isolinux/isolinux.cfg

# Verbose booting output
sed -i 64s/quiet/#quiet/ $M_WD/isolinux/isolinux.cfg

# Moving the squashfs.img to current directory
mv $M_WD/LiveOS/squashfs.img . 

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

unsquashfs -f -d $M_SFS squashfs.img 

# Removing the squashfs.img
rm -f squashfs.img

# Mounting the root root file system
mkdir $M_RFS
mount $M_SFS/LiveOS/rootfs.img $M_RFS

# Edit section 
# Disabling selinux
sed -i 7s/enforcing/disabled/ $M_RFS/etc/selinux/config

# Setting network

# ADD MORE

# Entering to chroot environment
# chroot $M_RFS  

# Disabling firewall
chroot $M_RFS systemctl disable firewalld > /dev/null 2>&1
chroot $M_RFS systemctl mask firewalld > /dev/null 2>&1
#rm -f $M_RFS/etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service
#rm -f $M_RFS/etc/systemd/system/multi-user.target.wants/firewalld.service
#ln -s /dev/null $M_RFS/etc/systemd/system/firewalld.service

# Remove unnecessary packages 
#chroot $M_RFS dnf -y remove firefox libreoffice-core cheese evolution gnome-contacts gnome-maps rhythmbox shotwell gnome-weather > /dev/null 2>&1
# dnf add a timestamp inside of the RPM database, ufff

# Changing time zone
chroot $M_RFS ln -fs /usr/share/zoneinfo/UTC /etc/localtime > /dev/null 2>&1
#ln -fs /usr/share/zoneinfo/UTC $M_RFS/etc/localtime 

# Umount the root file system
umount $M_RFS
rmdir $M_RFS

# Creating the new squashfs, may want to use XZ compression
mksquashfs $M_SFS/ squashfs.img -noappend -mkfs-fixed-time $B_TIME -content-fixed-time $B_TIME

# Carefully removing the squash file system
rm -rf $M_SFS

# Moving the squashfs.img to working directory
mv squashfs.img $M_WD/LiveOS/ 

# Setting permissions for squashfs.img
chmod 644 $M_WD/LiveOS/squashfs.img

# Creating the iso
mkisofs -J -l -r -cache-inodes --hide-rr-moved -hide-joliet-trans-tbl -input-charset utf-8 -V $M_WD -o $M_WD.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-info-table -boot-load-size 4 $M_WD

# Carefully removing working directory
rm -rf $M_WD

# Checking the new iso HASH

# ETC 
