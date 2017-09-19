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

DATE=20171011 #`date +%Y%m%d` # Current date
export SOURCE_DATE_EPOCH="$(date --utc --date="$DATE" +%s)" # defined by reproducible-builds.org.
export SOURCE_DATE_YYYYMMDD="$(date --utc --date="$DATE" +%Y%m%d)"

ROOT_UID=0	# Only users with $UID 0 have root privileges
DEBIAN_VERSION="debian-live-9.1.0-amd64-cinnamon.iso"	# Current Debian Cinammon live version
DEBIAN_HASH="f076da14065c56ae7b42aec07e501b0f2a9f43563b01d13254305e97e24f1e17  -" # the " -" is necessary for the comparative unless if "sed" is used SHA-256
KS_DVD=0	# SHA256 ()
M_WD=KC-$DATE	# Working directory to create the ISO
SERIAL="ICANN-DNSSEC-KC-$DATE" # Serial
SFR=squashfs-root	# Mount folder for squash root file system
#B_TIME=$(date --date="$DATE" +%s)  # Time for squashfs EPOCH with UTC and 00:00:00
#M_TIME="${DATE}00000000" # Time YYYYMMDDhhmmsscc to control the timestamps of the filesystem superblocks and other global components of the ISO file system
#F_TIME="${DATE}0000.00"  # Ext3 Filesystem time

# Confirmation source: http://stackoveM_SFlow.com/questions/1885525/how-do-i-prompt-a-user-for-confirmation-in-bash-script
echo "Warning this can be dangerous. It will use chroot command to remove packages, changes configurations, etc. \
So, if something is going wrong can change from your host system rather than from the Live CD image. \
You need to be root and execute under your own responsibility"
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

# Checking squashfs-tools source: http://stackoveM_SFlow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
# ADD check VERSION
command -v mksquashfs >/dev/null 2>&1 || { echo >&2 "Please install (with XZ support) the last squashfs-tools \
direct form GitHub https://github.com/squashfs-tools/squashfs-tools.git"; exit 1; }

#unsquashfs version 4.3 (2014/05/12)
#mksquashfs version 4.3-git (2014/09/12)

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

# Using xorriso with osirrox a more efficient way to copy the iso content#
# Creating the work directory
echo "Coping the iso"
mkdir $M_WD

xorriso -osirrox on -indev $DEBIAN_VERSION -extract / $M_WD

# Changing isolinux.cfg
echo "Reducing the boot menu time"

sed -i 's/^timeout .*$/timeout 1/' $M_WD/isolinux/isolinux.cfg

echo "Adding kerner options"
sed -i \
'7s/\bcomponents\b/& locales=en_US.UTF-8 net.ifnames=0 selinux=0 nopersistence nosound nobluetooth timezone=Etc\/UTC username=root live-media=removable STATICIP=frommedia modprobe.blacklist=pcspkr,hci_uart,btintel,btqca,btbcm,bluetooth,snd_hda_intel,snd_hda_codec_realtek,snd_soc_skl,snd_soc_skl_ipc,snd_soc_sst_ipc,snd_soc_sst_dsp,snd_hda_ext_core,snd_soc_sst_match,snd_soc_core,snd_compress,snd_hda_core,snd_pcm,snd_timer,snd,soundcore/' \
$M_WD/isolinux/menu.cfg

# Updating also grub.cfg
sed -i \
'27s/\bcomponents\b/& locales=en_US.UTF-8 net.ifnames=0 selinux=0 nopersistence nosound nobluetooth timezone=Etc\/UTC username=root live-media=removable STATICIP=frommedia modprobe.blacklist=pcspkr,hci_uart,btintel,btqca,btbcm,bluetooth,snd_hda_intel,snd_hda_codec_realtek,snd_soc_skl,snd_soc_skl_ipc,snd_soc_sst_ipc,snd_soc_sst_dsp,snd_hda_ext_core,snd_soc_sst_match,snd_soc_core,snd_compress,snd_hda_core,snd_pcm,snd_timer,snd,soundcore/' \
$M_WD/boot/grub/grub.cfg

# Moving the squashfs.img to current directory
mv $M_WD/live/filesystem.squashfs .

# Using unsquashfs a more efficient way to copy the file system
# By default unsquashfs in squashfs-root folder
echo "unsquashfs the file system"
unsquashfs filesystem.squashfs

# Removing the squashfs.img
rm -f filesystem.squashfs

# Edit section
echo "Setting network"

echo -e "192.168.0.2 \thsm" >> $SFR/etc/hosts

rm -f $SFR/etc/network/interfaces.d/setup

cat > $SFR/etc/network/interfaces.d/kc-network << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address 192.168.0.1
  netmask 255.255.255.0
  network 192.168.0.0
  broadcast 192.168.0.255
  gateway 192.168.0.254

auto eth1
iface eth1 inet static
  address 192.168.0.3
  netmask 255.255.255.0
  network 192.168.0.0
  broadcast 192.168.0.255
  gateway 192.168.0.254
EOF

# AEP Software
# Check install -p, --preserve-timestamps
echo "Instaling AEP Software"
install -m 755 -d $SFR/opt/Keyper
install -m 755 -d $SFR/opt/Keyper/bin
install -m 755 -d $SFR/opt/Keyper/PKCS11Provider
install -m 755 -d $SFR/opt/Keyper/docs
install -p -m 555 ./opt/Keyper/bin/*              $SFR/opt/Keyper/bin
install -p -m 444 ./opt/Keyper/PKCS11Provider/*   $SFR/opt/Keyper/PKCS11Provider
install -p -m 444 ./opt/Keyper/docs/*             $SFR/opt/Keyper/docs

# ICANN Software & Scripts
echo "Instaling ICANN Software and Scripts"
install -m 755 -d $SFR/opt/icann
install -m 755 -d $SFR/opt/icann/bin
install -m 755 -d $SFR/opt/icann/dist
install -p -m 555 ./opt/icann/bin/*   $SFR/opt/icann/bin
install -p -m 555 ./opt/icann/dist/*  $SFR/opt/icann/dist

# DNSSEC Configurations Files
echo "Instaling DNSSEC Configurations Files"
install -m 755 -d $SFR/opt/dnssec
install -p -m 444 ./opt/dnssec/*    $SFR/opt/dnssec

# Profile
# File created as ROOT
echo "export PATH=.:/opt/icann/bin:/opt/Keyper/bin:\$PATH" >> $SFR/etc/profile.d/kc.sh

# Serial
# File created as ROOT
echo "Serial: $SERIAL"  >>  $SFR/etc/SERIAL

# Seting root account with not password
echo "root without a password"
cat << EOF | chroot $SFR
passwd -d root
EOF
touch $SFR/var/lib/live/config/user-setup

# X root autologin due a kernel module username=root
echo "X root auto login"
sed -i --regexp-extended \
    '11s/.*/#&/' \
$SFR/etc/pam.d/lightdm-autologin

# Cinnamon
echo "Custom Cinnamon"
# look touch /var/lib/live/config/xscreensaver


# Printer


# Mount Point
mkdir -p $SFR/media/HSMFD
mkdir -p $SFR/media/HSMFD_
mkdir -p $SFR/media/KSR


# Disabling more services
echo "Lower systemd's DefaultTimeoutStopSec"
sed -i --regexp-extended \
    's/^#DefaultTimeoutStopSec=.*$/DefaultTimeoutStopSec=5s/' \
$SFR/etc/systemd/system.conf

echo "Disabling ssh-agent"
sed -i 's/^use-ssh-agent/#use-ssh-agent/' $SFR/etc/X11/Xsession.options

# Remove unnecessary packages
# !!!Check timestamp inside of the apt database to create a reproducible build
echo "Removing unwanted packages"
cat << EOF | chroot $SFR
apt-get --yes purge '^firefox-esr*' '^libreoffice*' '^aspell*' '^hunspell*' '^myspell*' '^task-*'
EOF

# Deinstall dependencies of the just removed packages
#****Check THIS
#echo "Removing dependencies"
#cat << EOF | chroot $SFR
#apt-get --yes --purge autoremove
#EOF


# Seting filesystem timestamp
#for file in $(find "$SFR" -mtime 0)
#do
#	touch -a -m -h -t $F_TIME $file
#done

# Creating the new squashfs, may want to use XZ compression
echo "Creating the new squashfs"
mksquashfs $SFR/ filesystem.squashfs -noappend -comp xz # -mkfs-fixed-time $B_TIME -content-fixed-time $B_TIME

# Carefully removing the squash file system
rm -M_SF $SFR

# Moving the squashfs to working directory
mv filesystem.squashfs $M_WD/live/

# Setting permissions for squashfs.img
chmod 644 $M_WD/live/filesystem.squashfs

# Change the timestamp for the modified files
#for files in $(find "$M_WD" -mtime 0)
#do
#	touch -a -m -h -t $F_TIME $files
#done

## Creating the iso
echo "Creating the iso"
xorriso -outdev $M_WD.iso -volid ${M_WD/-/_} \
 -map $M_WD / -chmod 0755 / -- -boot_image isolinux dir=/isolinux \
 -boot_image isolinux system_area=/usr/lib/ISOLINUX/isohdpfx.bin \
 -boot_image any next -boot_image any efi_path=boot/grub/efi.img \
 -boot_image isolinux partition_entry=gpt_basdat

## Carefully removing working directory
rm -rf $M_WD

# Checking the new iso HASH

# END
#isolinux
#mksquashfs-tools
#xorriso
#libbsd-dev
