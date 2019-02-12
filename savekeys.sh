#!/bin/bash

SENSITIVE_UUID="1709-56B9"
PUBLIC_UUID=""



tar zcf "${TARBALL}" "${BACKUPDIR}"
gpg --import /etc/keymaster.pub
echo "$(gpg --list-keys --fingerprint \
	| grep masterkey -B1 | head -1 \
	| sed "s/.*\= \(.*\)/\1/"|tr -d '[:space:]' \
	):6:" | gpg --import-ownertrust;

disk=$(sudo dmesg|tail|grep "Attached.*removable disk"|sed "s/.* \[\([a-zA-Z0-9]\+\)\] .*/\1/")

echo -n "Please insert offline backup SENSITIVE thumbdrive now and press enter"
read junk
PART=$(fdisk -l |grep sd[a-z]|grep -v Disk|tail -n1|sed "s/ .*//")
while [ "${PART}" == "" ]; do
   sleep 1
   echo -n "."
done 
# SENSITIVE INSERTED...

PART=$(fdisk -l |grep sd[a-z]|grep -v Disk|tail -n1|sed "s/ .*//")
sudo mkdir /offline
sudo mount ${PART} /offline
if [ ! -f /offline/.sensitive ]; then
    echo "Inserted Thumbdrive is NOT the sensitive thumb!!!"
    umount /offline
    exit 0
fi
echo -n "Copying Sensitive data now..."
echo >> /offline/"${lname},${fname}.csv" <<EOF
"${email}","${lname}","${fname}","${KEYID}","${adminpin}"
EOF
gpg -e -r masterkey@cboe.com -o /offline/"${GPGBALL}" "${TARBALL}"
echo "Done"
umount /offline

echo -n "Please remove SENSITIVE thumbdrive now."
while [ "${PART}" != "$(fdisk -l|grep -o ${PART})" ]; do
   sleep 1
   echo -n "."
done
# SENSTIVE REMOVED

echo -n "Please insert PUBLIC KEY thumbdrive now and press enter."
read junk
PART=$(fdisk -l |grep sd[a-z]|grep -v Disk|tail -n1|sed "s/ .*//")
while [ "${PART}" == "" ]; do
   sleep 1
   echo -n "."
done 

# PUBLIC KEY THUMB INSERTED
sudo mkdir /public
sudo mount /dev/${PART} /public
if [ -f /public/.sensitive ]; then
    echo "Inserted Thumbdrive is the sensitive thumb!!! REMOVE IMMEDIATELY!"
    umount /public
    exit 0
fi
echo -n "Copying Public Key data now..."
cp "${BACKUPDIR}/keys_public.gpg" "/public/$(date +%F)-${lname},${fname}-gpgkey.pub"
gpg --export-ssh-key $KEYID > "/public/$(date +%F)-${lname},${fname}-sshkey.pub"
umount /public
echo "Done"

echo -n "Please remove PUBLIC KEY thumbdrive now."
PART=$(fdisk -l |grep sd[a-z]|grep -v Disk|tail -n1|sed "s/ .*//")
while [ "${PART}" != "" ]; do
   sleep 1
   echo -n "."
done
# PUBLIC KEY THUMB REMOVED
rm -rf "${BACKUPDIR}"
rm -rf "${TARBALL}"
rm -rf "${GPGBALL}"
