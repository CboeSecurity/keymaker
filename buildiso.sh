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
##  Clear previous live-build environment              ##
#########################################################
if [ ! -d live ]; then
   mkdir live
fi
cd live
cwd=$(pwd)
lb clean

# clean out any cached copies of our configs...
if [ -f ./live/chroot/etc/rc.local ]; then
    rm -f ./live/chroot/etc/rc.local
fi

# clean out any cached copies of our scripts...
if [ -d live/chroot/usr/local/bin ]; then
    rm -f ./live/chroot/usr/local/bin/*
fi

#########################################################
##  Prepare live-build environment                     ##
#########################################################
lb config noauto \
	--mode debian \
	--architectures amd64 \
	--linux-flavours amd64 \
	--debian-installer false \
	--archive-areas "main contrib" \
	--apt-indices false \
	--memtest none \
	--bootappend-live "boot=live toram noprompt quiet silent username=root --"\
	--bootloader syslinux \	
	"${@}"
#	--archive-areas "main contrib non-free" \

echo "curl gnupg2 gnupg-agent \
     cryptsetup scdaemon pcscd \
     libusb-dev libusb-1.0-0 libusb-1.0-0-dev \
     usbutils dieharder \
     python3-pexpect \
     python \
     dirmngr \
     haveged rng-tools \
     hopenpgp-tools \
     swig libpcsclite-dev \
     python3-pip \
     python-gnupg at openssl \
     util-linux \
     tmux vim \
     secure-delete " >> config/package-lists/my.list.chroot
#     infnoise \
#     yubikey-personalization \

#########################################################
##  Support the Infinite Noise TRNG                    ##
#########################################################
if [ ! -f 13-37.org-code.asc ]; then 
wget -O 13-37.org-code.asc https://13-37.org/files/pubkey.gpg 
gpg --import-options import-show --dry-run --import < 13-37.org-code.asc
apt-key add 13-37.org-code.asc
echo "deb http://repo.13-37.org/ stable main" > /etc/apt/sources.list.d/infnoise.list
fi

apt update
cp 13-37.org-code.asc config/archives/infnoise.key.chroot
echo "deb http://repo.13-37.org/ stable main" > config/archives/infnoise.list.chroot 
echo "libftdi1 infnoise" > config/package-lists/infnoise.list.binary
mkdir -p ${cwd}/config/includes.chroot/etc
echo "#!/bin/bash" > ${cwd}/config/includes.chroot/etc/rc.local
echo "dpkg -i /lib/live/mount/medium/pool/main/libf/libftdi/*deb /lib/live/mount/medium/pool/main/i/infnoise/*deb" >> ${cwd}/config/includes.chroot/etc/rc.local
echo 'if [ "$(infnoise -l |grep -o Serial:.*|wc -c)" -gt 10 ]; then echo "infnoise plugged in";systemctl disable haveged; systemctl stop haveged;fi' >> ${cwd}/config/includes.chroot/etc/rc.local
chmod 755 ${cwd}/config/includes.chroot/etc/rc.local

#########################################################
##  Support the OneRNG TRNG                            ##
#########################################################
apt install rng-tools python-gnupg
ONERNGVER="3.6-1"
ONERNGSHA256="a9ccf7b04ee317dbfc91518542301e2d60ebe205d38e80563f29aac7cd845ccb"
if [ ! -f onerng_${ONERNGVER}_all.deb ]; then
  wget https://github.com/OneRNG/onerng.github.io/blob/master/sw/onerng_${ONERNGVER}_all.deb?raw=true -O onerng_${ONERNGVER}_all.deb
  CHKHASH=$(shasum -a 256 onerng_${ONERNGVER}_all.deb|sed "s/ .*//")
  if [ "${CHKHASH}" != "${ONERNGSHA256}" ]; then
    echo "ONERNG TRNG Download Hash is invalid!!!"
    exit 1
  fi
fi

if [ ! -d ${cwd}/config/includes.chroot/etc ]; then 
   mkdir -p ${cwd}/config/includes.chroot/etc
fi

if [ ! -d ${cwd}/config/includes.chroot/usr/share ]; then 
   mkdir -p ${cwd}/config/includes.chroot/usr/share
fi
cp onerng_${ONERNGVER}_all.deb ${cwd}/config/includes.chroot/usr/share
if [ ! -f ${cwd}/config/includes.chroot/etc/rc.local ]; then
echo "#!/bin/bash" > ${cwd}/config/includes.chroot/etc/rc.local
fi 
echo "dpkg -i /usr/share/onerng*deb" >> ${cwd}/config/includes.chroot/etc/rc.local
echo 'if [ "$(lsusb|grep OpenMoko|sed "s/.*ID \([0-9a-z:]\{9\}\).*/\\1/")" == "1d50:6086" ]; then echo "OneRNG plugged in"; systemctl disable haveged; systemctl stop haveged; fi' >> ${cwd}/config/includes.chroot/etc/rc.local

#########################################################
##  End in rc.local				       ##
#########################################################
echo "exit 0" >> ${cwd}/config/includes.chroot/etc/rc.local

#########################################################
##  Hack in rc.local support			       ##
#########################################################
mkdir -p ${cwd}/config/includes.chroot/etc/systemd/system
echo """[Unit]
Description=/etc/rc.local compatibility

[Service]
Type=oneshot
ExecStart=/etc/rc.local
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
""" > ${cwd}/config/includes.chroot/etc/systemd/system/rc-local.service

#########################################################
##  Yubikey library download, compile, install to live ##
#########################################################
apt install -y gcc make libssl-dev
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
