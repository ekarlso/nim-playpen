#!/bin/bash

export WORKSPACE=$1
export VERSION=$2

# Install nim and nim-vm globally
sudo wget https://raw.githubusercontent.com/ekarlso/nim-vm/master/bin/nim-vm -O $WORKSPACE/usr/local/bin/nim-vm
sudo chmod +x $WORKSPACE/usr/local/bin/nim-vm

sudo chroot $WORKSPACE su - -c "NIMVM_VERSION_LINK=0 nim-vm -d /usr/local/nim install $VERSION"
sudo chroot $WORKSPACE su - -c "chmod +x /usr/local/nim/versions/$VERSION/bin/nim"
sudo chroot $WORKSPACE su - -c "mkdir /mnt/runs"
sudo chroot $WORKSPACE su - -c "chown nim /mnt/runs"
