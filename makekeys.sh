#!/usr/bin/env bash

version=1
if [ $# -ne 3 ]; then
    echo "Syntax error, try: $0 \"<user first name>\" \"<user last name>\" \"<email address>\""	
    exit 1
else
    fname=$1
    lname=$2
    name="${lname}, ${fname}"
    email=$3
fi
keylength=4096

env_vars_file=keygen.env

#config
export GNUPGHOME=$(mktemp -d)
#GNUPGHOME="$(pwd)/.gnupg"
echo "GNUPGHOME is ${GNUPGHOME}"
#master random-passphrase
passphrase=$(gpg --gen-random -a 0 24)
#passphrase=aaaaaaaa

GPGOPT="--no-tty --batch"

rm -rf $GNUPGHOME
mkdir -m 0700 $GNUPGHOME
cp /etc/gpg.conf $GNUPGHOME 
chmod 600 $GNUPGHOME/gpg.conf
touch $GNUPGHOME/{pub,sec}ring.gpg


cat >$GNUPGHOME/initial.conf <<EOF
    Key-Type: RSA
    Key-Length: ${keylength}
    Subkey-Type: RSA
    Subkey-Length: ${keylength}
    Subkey-Usage: sign
    Name-Real: ${name}
    Name-Comment: Automatic Boot-GPG Generated (v${version})
    Name-Email: ${email}
    Passphrase: ${passphrase}
    Expire-Date: 0
    # Do a commit here, so that we can later print "done" :-)
    %commit
EOF

# Generate master and signing subkey using above "foo" config
echo "Generating Master key and Signing Subkey..."
gpg ${GPGOPT} --gen-key $GNUPGHOME/initial.conf
echo "Done"

# Find the KEYID of the master key to do add subkeys, edit, etc
KEYID=$(gpg --list-keys --with-colons|grep pub|cut -d":" -f5)

GPGGENSUBKEY="${GPGOPT} --expert --display-charset utf-8 --passphrase ${passphrase} --command-fd 0"
echo -n "Generating Encryption subkey..."
# Create the Encryption subkey followed by the Authentication subkey
echo addkey$'\n'6$'\n'${keylength}$'\n'0$'\n'y$'\n'y$'\n'save$'\n' | LC_ALL= LANGUAGE=en gpg ${GPGGENSUBKEY} --edit-key $KEYID
echo "Done"
echo -n "Generating Authentication subkey..."
echo addkey$'\n'8$'\n'S$'\n'E$'\n'A$'\n'q$'\n'${keylength}$'\n'0$'\n'save$'\n' | LC_ALL= LANGUAGE=en gpg ${GPGGENSUBKEY} --edit-key $KEYID
echo "Done"

GPGEXPORTOPT="${GPGOPT} --armor --passphrase-fd 0 --pinentry loopback" 
####### EXPORTING SECRET SUBKEYS ##########"
key_file="${GNUPGHOME}/exported-masterkey.key"
echo -n "Exporting Secret Keys to ${key_file}..."
echo ${passphrase}| gpg ${GPGEXPORTOPT} --export-secret-keys > ${key_file}
echo "Done"

####### EXPORTING SECRET SUBKEYS ##########"
subkey_file="${GNUPGHOME}/exported-subkeys.key"
echo -n "Exporting Secret Subkeys to ${subkey_file}..."
echo ${passphrase}| gpg --armor --batch $OPT --passphrase-fd 0 --pinentry loopback  --export-secret-subkeys > ${subkey_file}
echo "Done"

BKROOT="gpgbackup-${name}"
BACKUPDIR="${BKROOT}.d"
TARBALL="${BKROOT}.tgz"
GPGBALL="${BKROOT}.tgz.enc"
gpg -a --export ${email} > keys_public.gpg
cp -arf $GNUPGHOME "${BACKUPDIR}"
gpg -a --export ${email} > "${BACKUPDIR}"/keys_public.gpg

echo "export passphrase=\"${passphrase}\"" > ${env_vars_file}
echo "export GNUPGHOME=\"${GNUPGHOME}\"">> ${env_vars_file}
echo "export KEYID=\"${KEYID}\"" >> ${env_vars_file}
echo "export fname=${fname}" >> ${env_vars_file}
echo "export lname=${lname}" >> ${env_vars_file}
echo "export email=${email}" >> ${env_vars_file}

gpg --export $KEYID | hokey lint

echo ""
echo "##################################################"
echo "##  REMEMBER to source: ". ${env_vars_file}"  !!! "
echo "##################################################"
