#!/bin/bash

set -eux

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

export WORKSPACE=${WORKSPACE:-$(mktemp -d)}
export TARGET=${TARGET:-$HOME/versions}
export VERSION=${VERSION:-devel}

mkdir -p $TARGET

bash $DIR/build_chroot.sh
bash $DIR/install_nim.sh $WORKSPACE $VERSION

sudo cp $DIR/eval.sh $WORKSPACE/usr/local/bin

sudo mv $WORKSPACE $TARGET/$VERSION