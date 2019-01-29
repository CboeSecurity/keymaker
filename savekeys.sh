#!/bin/bash

tar zcvf "${TARBALL}" "${BACKUPDIR}"
gpg --import keymaster.pub
gpg -e -r keymaster@cboe.com -o "${GPGBALL}"
echo << EOF
"${email}","${lname}","${fname}","${KEYID}"EOF > ${name}.csv

