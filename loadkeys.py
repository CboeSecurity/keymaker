#!/usr/bin/env python3

'''
gpg/card> admin
Admin commands are allowed

gpg/card> passwd
gpg: OpenPGP card no. D2760001240102010006061158870000 detected

1 - change PIN
2 - unblock PIN
3 - change Admin PIN
4 - set the Reset Code
Q - quit

Your selection? 1
PIN changed.

1 - change PIN
2 - unblock PIN
3 - change Admin PIN
4 - set the Reset Code
Q - quit

Your selection? q

gpg/card> q 
'''

import sys
import pexpect
import os
from random import randint
from getpass import getpass

oldpin = '123456'
newpin = '123456'
oldadminpin = '12345678'
adminpin = oldadminpin
newadminpin = str(randint(1,99999999)).zfill(8)

passphrase = os.environ['passphrase']
keyid = os.environ['KEYID']
lname = os.environ['lname']
fname = os.environ['fname']
email = os.environ['email']

# LOG FILE
logfile = open('loadkeys.log','w')
def logtitle(title):
    logfile.write("\n\n\n##################################################################\n".encode())
    logfile.write(("###  %s\n"%title).encode())
    logfile.write("##################################################################\n".encode())

# reset the card first
logtitle("ykman card reset")
p = pexpect.pty_spawn.spawn('ykman openpgp reset')
p.logfile = logfile
ret = p.expect('restore factory settings?')
p.sendline('y')
ret = p.expect(['Success!','Error: No YubiKey detected!'])
if ret == 0:
    print("Yubikey reset successfully")
else:
    print("Couldn't reset openpgp... is this a bare metal host and is the yubikey present?")

testpin = getpass('Please Enter your *new* PIN: ') 
testpin2 = getpass('Please Reenter your *new* PIN: ') 
if testpin == testpin2:
    newpin = testpin



# set the new pins
logtitle("gpg card-edit new pins")
p = pexpect.pty_spawn.spawn('gpg --card-edit --pinentry-mode loopback')
p.logfile = logfile
p.expect('gpg/card>')
p.sendline('admin')
p.expect('are allowed')
p.sendline('passwd')
ret = p.expect(['Your selection?','No such device'])
if ret == 1:
    print('Device not connected!')
    p.sendline('q')
    p.expect('gpg/card>')
    p.sendline('q')
    sys.exit(1)
p.sendline('1')
p.expect('Enter passphrase')
p.sendline(oldpin)
p.sendline(newpin)
p.sendline(newpin)
p.expect('PIN changed')
p.expect('Your selection?')
p.sendline('3')
p.expect('Enter passphrase')
p.sendline(oldadminpin)
p.sendline(newadminpin)
p.sendline(newadminpin)
p.expect('PIN changed')
p.sendline('q')
adminpin = newadminpin

p.expect('gpg/card>')
p.sendline('name')
p.expect('Cardholder\'s surname:')
p.sendline(lname)
p.expect('Cardholder\'s given name:')
p.sendline(fname)

ret = p.expect(['gpg/card','Enter passphrase'])
if ret == 1:
    p.sendline(adminpin)
    p.expect('gpg/card>')
p.sendline('lang')
p.expect('Language preferences:')
p.sendline('en')

ret = p.expect(['gpg/card','Enter passphrase'])
if ret == 1:
    p.sendline(adminpin)
    p.expect('gpg/card>')
p.sendline('login')
p.expect('account name')
p.sendline(email)

p.expect('gpg/card>')
p.sendline('q')

# set the touch policies
logtitle("ykman touch policies to fixed - sig")
p = pexpect.pty_spawn.spawn('ykman openpgp touch --admin-pin %s -f sig fixed'%(adminpin))
p.logfile = logfile
ret = p.expect(['Touch policy successfully set','Error: No YubiKey detected!'])
if ret == 0:
    print("Successfully Updated a Yubikey touch policy")
else:
    print("Failed to update a Yubikey touch policy")

logtitle("ykman touch policies to fixed - encrypt")
p = pexpect.pty_spawn.spawn('ykman openpgp touch --admin-pin %s -f enc fixed'%(adminpin))
p.logfile = logfile
ret = p.expect(['Touch policy successfully set','Error: No YubiKey detected!'])
if ret == 0:
    print("Successfully Updated a Yubikey touch policy")
else:
    print("Failed to update a Yubikey touch policy")

logtitle("ykman touch policies to fixed - auth")
p = pexpect.pty_spawn.spawn('ykman openpgp touch --admin-pin %s -f aut fixed'%(adminpin))
p.logfile = logfile
ret = p.expect(['Touch policy successfully set','Error: No YubiKey detected!'])
if ret == 0:
    print("Successfully Updated a Yubikey touch policy")
else:
    print("Failed to update a Yubikey touch policy")

'''
ykman openpgp touch --admin-pin 12345678 -f sig on
ykman openpgp touch --admin-pin 12345678 -f enc on
ykman openpgp touch --admin-pin 12345678 -f aut on
'''
'''
gpg> key 1

sec  rsa4096/0x8191ACCD34BE4A72
     created: 2019-01-10  expires: never       usage: SCEA
     trust: ultimate      validity: ultimate
ssb* rsa4096/0xB412313296D2E621
     created: 2019-01-10  expires: never       usage: S   
ssb  rsa4096/0xD7A205F011EBE5BC
     created: 2019-01-10  expires: never       usage: E   
ssb  rsa4096/0xC3FFBB7859ADA9AD
     created: 2019-01-10  expires: never       usage: A   
[ultimate] (1). b, a (Automatic Boot-GPG Generated (v1)) <a@b>

gpg> keytocard
Please select where to store the key:
   (1) Signature key
   (3) Authentication key
Your selection? 1

'''

# program in the keys
logtitle("gpg edit-key load keys to yubikey")
p = pexpect.pty_spawn.spawn('gpg --pinentry-mode loopback --edit-key %s'%(keyid))
p.logfile = logfile
p.expect('gpg>')
p.sendline('key 1')
p.expect('gpg>')
p.sendline('keytocard')
ret = p.expect(['Your selection?','No such device'])
if ret == 1:
    print('Device not connected!')
    p.sendline('q')
    sys.exit(1)
p.sendline('1')
ret = p.expect(['Enter passphrase:','Replace existing key?'])
if ret==1:
    p.sendline('y')
    p.expect('Enter passphrase:')
p.sendline(passphrase)
ret = p.expect(['Enter passphrase:','gpg>'])
if ret==0:
    p.sendline(adminpin)
    ret == p.expect(['Enter passphrase:','gpg>','SCEA'])
    if ret == 0:
        p.sendline(adminpin)
        p.expect('gpg>')
p.sendline('key 1')


p.expect('gpg>')
p.sendline('key 2')
p.expect('gpg>')
p.sendline('keytocard')
p.expect('Your selection?')
p.sendline('2')
ret = p.expect(['Enter passphrase:','Replace existing key?'])
if ret==1:
    p.sendline('y')
    p.expect('Enter passphrase:')
p.sendline(passphrase)
ret == p.expect(['Enter passphrase:','gpg>','SCEA'])
if ret == 0:
    p.sendline(adminpin)
ret == p.expect(['Enter passphrase:','gpg>','SCEA'])
## if NOT gpg, always send the adminpin?... input looks like '\r       \r    '
if ret == 0:
    p.sendline(adminpin)
    p.expect('gpg>')
p.sendline('key 2')


p.expect('gpg>')
p.sendline('key 3')
p.expect('gpg>')
p.sendline('keytocard')
p.expect('Your selection?')
p.sendline('3')
ret = p.expect(['Enter passphrase:','Replace existing key?'])
if ret==1:
    p.sendline('y')
    p.expect('Enter passphrase:')
p.sendline(passphrase)
ret = p.expect(['Enter passphrase:','gpg>'])
if ret==0:
    p.sendline(adminpin)
    ret == p.expect(['Enter passphrase:','gpg>','SCEA'])
    if ret == 0:
        p.sendline(adminpin)
        p.expect('gpg>')
p.sendline('key 3')


p.expect('gpg>')
p.sendline('q')
p.expect('Save changes')
p.sendline('y')

