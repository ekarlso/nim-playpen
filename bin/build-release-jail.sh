#!/bin/bash -eux

# Build a chroot
sudo yum install -y yum-utils

set -o errexit -o nounset -o pipefail
umask 022

VERSION=$1

VERSIONS_DIR=$HOME/versions
DEST=$VERSIONS_DIR/$VERSION

mkdir -p $VERSIONS_DIR

WORKSPACE=${WORKSPACE:-$(mktemp -d)}

mkdir -p $WORKSPACE/var/lib/rpm

rpm -r=$WORKSPACE --initdb

yumdownloader --destdir=/tmp fedora-repos fedora-release
sudo rpm --root $WORKSPACE -ivh /tmp/fedora-release*rpm /tmp/fedora-repos*rpm

sudo yum --installroot=$WORKSPACE -y install \
    coreutils \
    shadow-utils \
    procps-ng \
    util-linux \
    filesystem \
    grep

sudo yum --installroot=$WORKSPACE -y install \
    gcc \
    glibc-devel \
    git

sudo mkdir $WORKSPACE/dev/shm
sudo rm $WORKSPACE/dev/null
sudo mknod -m 666 $WORKSPACE/dev/null c 1 3
sudo mknod -m 644 $WORKSPACE/dev/urandom c 1 9

sudo cp /etc/resolv.conf $WORKSPACE/etc/resolv.conf

# Nim setup
sudo chroot $WORKSPACE useradd -m nim

# Install nim and nim-vm globally
sudo wget https://raw.githubusercontent.com/ekarlso/nim-vm/master/bin/nim-vm -O $WORKSPACE/usr/local/bin/nim-vm
sudo chmod +x $WORKSPACE/usr/local/bin/nim-vm

sudo chroot $WORKSPACE su - -c "NIMVM_VERSION_LINK=0 nim-vm -d /usr/local/nim install $VERSION"
sudo chroot $WORKSPACE su - -c "chmod +x /usr/local/nim/versions/devel/bin/nim"
sudo chroot $WORKSPACE su - -c "mkdir /mnt/runs"
sudo chroot $WORKSPACE su - -c "chown nim /mnt/runs"

# Move the chroot dir over to the right place
sudo rm -rf $DEST
sudo mv $WORKSPACE $DEST
