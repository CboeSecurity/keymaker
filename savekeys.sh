#!/bin/bash

SENSITIVE_UUID="1708-56B9"
PUBLIC_UUID="13CC-2705"



rm -rf "${BACKUPDIR}"/S*

tar zcf "${TARBALL}" "${BACKUPDIR}"
gpg --import /etc/keymaster.pub
masteremail=$(gpg /etc/keymaster.pub 2>/dev/null |grep uid|sed "s/.*<\(.*\)>.*/\1/")
echo "$(gpg --list-keys --fingerprint \
	| grep ${masteremail} -B1 | head -1 \
	| sed "s/.*\= \(.*\)/\1/"|tr -d '[:space:]' \
	):6:" | gpg --import-ownertrust;

disk=$(sudo dmesg|tail|grep "Attached.*removable disk"|sed "s/.* \[\([a-zA-Z0-9]\+\)\] .*/\1/")

echo -n "Please insert offline backup SENSITIVE thumbdrive now"
while [ ""$(blkid|grep "${SENSITIVE_UUID}"|sed "s/:.*//") == "" ]; do
   sleep 1
   echo -n "."
done 
# SENSITIVE INSERTED...

PART=$(blkid|grep "${SENSITIVE_UUID}"|sed "s/:.*//")
if [ ! -d /offline ]; then
    sudo mkdir /offline
fi 
sleep 0.5
sudo mount ${PART} /offline
if [ ! -f /offline/.sensitive ]; then
    echo "Inserted Thumbdrive is NOT the sensitive thumb!!!"
    umount /offline
    exit 0
fi
echo ""
echo -n "Copying Sensitive data now..."
adminpin=$(cat ${BACKUPDIR}/loadkeys.log|grep AdminPin:|sed "s/AdminPin://")
serialnum=$(gpg --card-status|grep Serial|sed "s/Serial.*\.\.\.: //")
date=$(date "+%F %T%Z")
#cat >> /offline/"${lname},${fname}.csv" <<EOF
#"${email}","${lname}","${fname}",${KEYID},${adminpin},${serialnum},${date}
#EOF
cat "${BACKUPDIR}/${lname},${fname}.csv" >> /offline/allusers.csv 
cat "${BACKUPDIR}/${lname},${fname}.csv" >> "/offline/${lname},${fname}.csv"
#tail -n1 /offline/"${lname},${fname}.csv" >> /offline/allusers.csv
gpg -e -r ${masteremail} -o /offline/"${GPGBALL}" "${TARBALL}"
echo "Done"
umount /offline

echo -n "Please remove SENSITIVE thumbdrive now."
while [ "${SENSITIVE_UUID}" == "$(blkid|grep -o ${SENSITIVE_UUID})" ]; do
   sleep 1
   echo -n "."
done
# SENSTIVE REMOVED

echo ""
echo -n "Please insert PUBLIC KEY thumbdrive now."
while [ ""$(blkid|grep "${PUBLIC_UUID}"|sed "s/:.*//") == "" ]; do
   sleep 1
   echo -n "."
done 

# PUBLIC KEY THUMB INSERTED
PART=$(blkid|grep "${PUBLIC_UUID}"|sed "s/:.*//")
if [ ! -d /public ]; then
    sudo mkdir /public
fi

sleep 0.5
sudo mount ${PART} /public
if [ -f /public/.sensitive ]; then
    echo "Inserted Thumbdrive is the sensitive thumb!!! REMOVE IMMEDIATELY!"
    umount /public
    exit 0
fi
echo ""
echo -n "Copying Public Key data now..."
cp "${BACKUPDIR}/keys_public.gpg" "/public/$(date +%F)-${lname},${fname}-gpgkey.pub"
gpg --export-ssh-key $KEYID > "/public/$(date +%F)-${lname},${fname}-sshkey.pub"
umount /public
echo "Done"

echo -n "Please remove PUBLIC KEY thumbdrive now."
while [ "${PUBLIC_UUID}" != "$(blkid|grep -o ${PUBLIC_UUID})" ]; do
   sleep 1
   echo -n "."
done
# PUBLIC KEY THUMB REMOVED
srm -r "${BACKUPDIR}"
srm -r "${TARBALL}"
echo "Backup (and cleanup) Complete!"
