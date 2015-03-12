#!/bin/bash -eux

# Build a chroot
sudo yum install -y yum-utils

set -o errexit -o nounset -o pipefail
umask 022

WORKSPACE=${WORKSPACE:-$(mktemp -d)}

mkdir -p $WORKSPACE/var/lib/rpm

rpm -r=$WORKSPACE --initdb

yumdownloader --destdir=/tmp fedora-repos fedora-release
sudo rpm --root $WORKSPACE -ivh /tmp/fedora-release*rpm /tmp/fedora-repos*rpm

# NOTE from def-: use tinycc / tcc for faster compilations
sudo wget https://copr.fedoraproject.org/coprs/lantw44/tcc/repo/fedora-21/lantw44-tcc-fedora-21.repo -O $WORKSPACE/etc/yum.repos.d/tinycc.repo

sudo yum --installroot=$WORKSPACE -y install \
    coreutils \
    shadow-utils \
    procps-ng \
    util-linux \
    filesystem \
    grep \

sudo yum --installroot=$WORKSPACE -y install \
    gcc \
    glibc-devel \
    git \
    tcc


sudo mkdir $WORKSPACE/dev/shm
sudo rm $WORKSPACE/dev/null
sudo mknod -m 666 $WORKSPACE/dev/null c 1 3
sudo mknod -m 644 $WORKSPACE/dev/urandom c 1 9

sudo cp /etc/resolv.conf $WORKSPACE/etc/resolv.conf

# Nim setup
sudo chroot $WORKSPACE useradd -m nim