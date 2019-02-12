#!/bin/sh

libyubikey_ver="libyubikey-1.13"
ykpers_ver="ykpers-1.19.0"

set -e

apt install -y netselect-apt live-build

owd=$(pwd)
#########################################################
##  Optimize downloads from fastest mirror site        ##
#########################################################
if [ ! -d /etc/live ]; then
    mkdir /etc/live
fi

if [ ! -f .distro_mirror ]; then
    mirror=$(netselect-apt 2>/dev/null|grep -m1 "://"|sed "s/[ 	]*//g")
    echo "${mirror}" > .distro_mirror
else
    mirror=$(cat .distro_mirror)
fi
echo """LB_MIRROR_BOOTSTRAP="$mirror"
LB_MIRROR_CHROOT_SECURITY="http://security.debian.org/"
LB_MIRROR_CHROOT_BACKPORTS="$mirror"
""" > /etc/live/build.conf

#########################################################
##  Prepare live-build environment                     ##
#########################################################
if [ ! -d live ]; then
   mkdir live
fi
cd live
cwd=$(pwd)
#lb clean

lb config noauto \
	--mode debian \
	--architectures amd64 \
	--linux-flavours amd64 \
	--debian-installer false \
	--archive-areas "main contrib" \
	--apt-indices false \
	--memtest none \
	"${@}"
#	--archive-areas "main contrib non-free" \

echo "curl gnupg2 gnupg-agent \
     cryptsetup scdaemon pcscd \
     libusb-dev libusb-1.0-0 libusb-1.0-0-dev \
     python3-pexpect \
     python
     dirmngr \
     haveged rng-tools \
     hopenpgp-tools \
     swig libpcsclite-dev \
     python3-pip \
     python-gnupg at openssl \
     secure-delete " >> config/package-lists/my.list.chroot
#     yubikey-personalization \

#########################################################
##  Yubikey library download, compile, install to live ##
#########################################################
apt install -y gcc make
if [ -f ${libyubikey_ver} ];
then
   rm -rf ${libyubikey_ver}
fi
if [ ! -f ${libyubikey_ver}.tar.gz ];
then
   wget https://developers.yubico.com/yubico-c/Releases/${libyubikey_ver}.tar.gz
fi 
tar xvf ${libyubikey_ver}.tar.gz 
cd ${libyubikey_ver}
if [ -f Makefile ]; then
make clean
fi
./configure && make -j3 && make install
make clean
./configure --prefix=${cwd}/config/includes.chroot/usr && make -j3 && make install
cd ..

#########################################################
##  ykpersonalize download, compile, install to live   ##
#########################################################
apt install libusb-dev
if [ -f ${ykpers_ver} ];
then
   rm -rf ${ykpers_ver}
fi
if [ ! -f ${ykpers_ver}.tar.gz ];
then
   wget https://developers.yubico.com/yubikey-personalization/Releases/${ykpers_ver}.tar.gz
fi 
tar xvf ${ykpers_ver}.tar.gz
cd ${ykpers_ver}
if [ -f Makefile ]; then
make clean
fi
./configure --prefix=${cwd}/config/includes.chroot/usr && make -j3 && make install
cd ..

apt install swig libpcsclite-dev python3-pip
#live/usr/local/lib/python2.7/dist-packages
pip3 install yubikey-manager
#/usr/local/lib/python3.5/dist-packages

mkdir -p ${cwd}/config/includes.chroot/usr/local/lib/python3.5/dist-packages
mkdir -p ${cwd}/config/includes.chroot/usr/local/lib/python2.7/dist-packages
pip3 install yubikey-manager -t ${cwd}/config/includes.chroot/usr/local/lib/python3.5/dist-packages
pip install yubikey-manager -t ${cwd}/config/includes.chroot/usr/local/lib/python2.7/dist-packages
mkdir -p ${cwd}/config/includes.chroot/usr/local/bin/
cp $(which ykman) ${cwd}/config/includes.chroot/usr/local/bin

#########################################################
##  Copy the CboeSec scripts used to generate gpg keys ##
#########################################################

mkdir -p ${cwd}/config/includes.chroot/etc
cp -L ${owd}/gpg.conf ${cwd}/config/includes.chroot/etc
cp -L ${owd}/keymaster.pub ${cwd}/config/includes.chroot/etc/keymaster.pub

mkdir -p ${cwd}/config/includes.chroot/usr/local/bin/
cp -L ${owd}/makekeys.sh ${cwd}/config/includes.chroot/usr/local/bin/makekeys
cp -L ${owd}/loadkeys.py ${cwd}/config/includes.chroot/usr/local/bin/loadkeys
cp -L ${owd}/savekeys.sh ${cwd}/config/includes.chroot/usr/local/bin/savekeys
chmod 755 ${cwd}/config/includes.chroot/usr/local/bin/*keys
#########################################################
##   finalize the live build gpg/ykpers environment    ##
#########################################################
lb build

cp live-image-amd64.hybrid.iso /shared/
echo "Done!!!"
