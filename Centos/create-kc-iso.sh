#!/bin/sh -x
#
# Creating a new KC DVD ISO based on the previous KC DVD ISO
# Adding SW components, recompress it into a SquashFS and create the new ISO. 
#
# To-do:
# Define the path for the working directory and also for the ISO. Maybe $1 and $2 
# Write the warning and consideration to run the scrip - need to be run in a Linux machine, recommendation a minimal virtual machine
# Verify the signature
# Sign this scrip
# Any way to check the scrip version?
# Verify the final hash of the ISO
# Add a clean up
# wget *.iso
# wget the custom KM-SW?, and all the other files?
# check if automount is disable
# make for any unix/linux distribution
# Verify the mksquashfs version 
# Instead of moving, copy and deleting the squashfs.img just unsquashfs from the original directory, them replace the old for the new.
#
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

# Be sure to verify that you will have sufficient space before running the script.
# This may require, for example, over 12.0 GiB of free space for Fedora 25 Workstation Live

# *CHANGE* #
##KCDVD_VERSION="KC-20161014.iso" # Current KC DVD ISO version
##KCDVD_HASH="991f7be8cfbc3b4bdb6f5e5f84092486755a08a3c36712e37a26ccd808631692" # SHA-256 of KC-20161014.iso
M_ISO="KC-20161014"		# Mount folder for the iso
# *CHANGE* #

ROOT_UID=0	# Only users with $UID 0 have root privileges
M_WD="KC-$(date +%Y%m%d)"	# Working directory to create the new ISO version = today
M_SMNT=squashmnt        	# Mount folder for mounting squash file system 
M_SFS=squashfs          	# Mount folder for squash file system
M_RFS=rootfs            	# Mount folder for root ext3fs file system 

# Update this function accordingly to the O/S changes
update_ext3fs()
{
# Entering to chroot environment
# Changing time zone just for this time!
chroot $M_RFS ln -fs /usr/share/zoneinfo/UTC /etc/localtime > /dev/null 2>&1
#ln -fs /usr/share/zoneinfo/UTC $M_RFS/etc/localtime 
 
# Updating /opt/icann/bin ksrsigner
##chown root:root ksrsigner
##chmod 555 ksrsigner
##if [[ ! sha256sum -c ksrsigner.sha256 ]]
##then
##	exit 1
##fi
##rsync -ar --inplace --progress ksrsigner $M_RFS/opt/icann/bin/
##if [[ ($(sha256sum $M_RFS/opt/icann/bin/ksrsigner)) != awk '{print $1}' ksrsigner.sha256 ]]
##then
##	exit 1
##fi

# *CHANGE* #
# for all binaries http://www.iitk.ac.in/LDP/LDP/abs/html/abs-guide.html#EX22A
# list is a file name and chmod permission
for bin in "ksrsigner 555" "printlog 755" "hsmfd-hash 755"
do
	set -- $bin # parses variable "bin"
	chown root:root $1
	chmod $2 $1
	#if ! sha256sum -c $1.sha256
	if [[ ! "$(sha256sum -c $1.sha256)" ]]
	then
		exit 1
	fi
	rsync -ar --inplace --progress $1 $M_RFS/opt/icann/bin/
	sha1=($(sha256sum $M_RFS/opt/icann/bin/$1))
	sha2=$(awk '{print $1}' $1.sha256)
	if [[ "$sha1" != "$sha2" ]]
	#if [[ "($(sha256sum $M_RFS/opt/icann/bin/$1))" != "$(awk '{print $1}' $1.sha256)" ]]
	then
		exit 1
	fi
done
}

# Confirmation source: http://stackoverflow.com/questions/1885525/how-do-i-prompt-a-user-for-confirmation-in-bash-script
echo "Warning this can be dangerous. If something is going wrong can change from your host system rather than from the Live CD image. You need to be root and execute under your own responsibility"
read -n 1 -r -p "Are you sure to continue [y/N]? " continue
echo    # Move to a new line
if [[ ! $continue =~ ^[Yy]$ ]]
then
	exit 1
fi

# Run as root source: http://www.iitk.ac.in/LDP/LDP/abs/html/abs-guide.html#EX2
if [ "$UID" -ne "$ROOT_UID" ]
then
  echo "Must be root to run this script."
  exit 1
fi

# Checking squashfs-tools source: http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
# ADD check VERSION
command -v mksquashfs >/dev/null 2>&1 || { echo >&2 "Please install squashfs-tools"; exit 1; }

# Checking rsync
command -v rsync >/dev/null 2>&1 || { echo >&2 "Please install rsync"; exit 1; }

# Checking xorriso
# Not in CentOS 5.5 command -v rsync >/dev/null 2>&1 || { echo >&2 "Please install xorriso"; exit 1; }

# Checking the ISO HASH
##echo "Calculating the ISO SHA-256 HASH of the $KCDVD_VERSION"
##iso_hash=($(sha256sum $KCDVD_VERSION))
##echo "SHA-256 HASH: $iso_hash"
##echo "KC-DVD  HASH: $KCDVD_HASH"
##if [ "$iso_hash" != "$KCDVD_HASH" ]
##then
##	echo "ERROR: SHA-256 hashes do not match, try to download again the $KCDVD_VERSION"
##	exit 1
##else
##	echo "SHA-256 HASH of the $KCDVD_VERSION match"
##fi
##
if [[ ! "$(sha256sum -c $M_ISO.iso.sha256)" ]]
then
	exit 1
fi

# Using OSIRROX a more efficient way to copy the iso content
##xorriso -osirrox on -indev $KCDVD_VERSION -extract / $M_WD
# Mounting the ISO
mkdir $M_ISO
mount -o loop $M_ISO.iso $M_ISO

# Creating the work directory
mkdir $M_WD

# Coping the entire ISO
rsync -ar --inplace --progress $M_ISO/ $M_WD
##cp -rdav $M_ISO/* $M_WD/ #rsync is better with progress information 

# umount the ISO it not longer needed
umount $M_ISO
rmdir $M_ISO

# Changing isolinux.cfg O/S DVD Version
sed -i s/$M_ISO/$M_WD/g $M_WD/isolinux/isolinux.cfg

# Moving the squashfs.img to current directory
mv $M_WD/LiveOS/squashfs.img . 

# Using unsquashfs a more efficient way to copy the file system 
# Mounting the squashfs.img
#mkdir $M_SMNT
#mount -o loop -t squashfs squashfs.img $M_SMNT
#
# Copy squashfs file system
#mkdir $M_SFS
#rsync -ar --inplace --progress $M_SMNT/ $M_SFS
#
# Umount the squashfs.img it not longer needed
#umount $M_SMNT
#rmdir $M_SMNT

unsquashfs -dest $M_SFS squashfs.img 

# Removing the squashfs.img
rm -f squashfs.img

# Just for this time, changing ext3fs.img owner to root
chown root:root $M_SFS/LiveOS/ext3fs.img

# Mounting the root root file system
mkdir $M_RFS
mount -o loop $M_SFS/LiveOS/ext3fs.img $M_RFS

# Edit section 
update_ext3fs

# Adding the icann-keytools
chown root:root icann-keytools-*
chmod 644 icann-keytools-*
if [[ ! "$(sha256sum -c icann-keytools-*.sha256)" ]]
then
	exit 1
fi
rsync -ar --inplace --progress icann-keytools-* $M_RFS/opt/icann/dist/

#if [[ "($(sha256sum $(ls -tr $M_RFS/opt/icann/dist/icann-keytools-*.tar.gz | tail -n 1)))" != "$(awk '{print $1}' icann-keytools-*.sha256)" ]]
sha1=($(sha256sum $(ls -tr $M_RFS/opt/icann/dist/icann-keytools-*.tar.gz | tail -n 1)))
sha2=$(awk '{print $1}' icann-keytools-*.sha256)
if [[ "$sha1" != "$sha2" ]]
then
	exit 1
fi

# SERIAL
sed -i s/$M_ISO/$M_WD/g $M_RFS/etc/SERIAL

# Umount the root file system
umount $M_RFS
rmdir $M_RFS

# Creating the new squashfs, may want to use XZ compression
mksquashfs $M_SFS/ squashfs.img -noappend

# Carefully removing the squash file system
rm -rf $M_SFS

# Moving the squashfs.img to working directory
mv squashfs.img $M_WD/LiveOS/ 

# Setting permissions for squashfs.img
chmod 555 $M_WD/LiveOS/squashfs.img

# Creating the iso
mkisofs -J -l -r -cache-inodes --hide-rr-moved -hide-joliet-trans-tbl \
	-V $M_WD -o $M_WD.iso -b isolinux/isolinux.bin -c isolinux/boot.cat \
	-no-emul-boot -boot-info-table -boot-load-size 4 $M_WD

# Carefully removing working directory
rm -rf $M_WD

# Creating the new iso HASH
sha256sum $M_WD.iso > $M_WD.iso.sha256

# END
