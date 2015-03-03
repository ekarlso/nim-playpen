#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd $HOME

sudo yum install -y git gcc make
sudo yum install -y clang glibc-devel glib2-devel libseccomp-devel systemd-devel

if [ ! -d "$HOME/playpen" ]; then
  git clone http://github.com/thestinger/playpen
  cd playpen
  make
fi

curl -q https://raw.githubusercontent.com/ekarlso/nim-vm/master/scripts/install.sh | bash
source ~/.bashrc

nim-vm use devel 2>/dev/null
if [ $? -eq 1 ]; then
    nim-vm install devel
    nim-vm use devel
fi

if [ ! -d "nimble" ]; then
    git clone https://github.com/nim-lang/nimble
    cd nimble
    nim c -r src/nimble install -y
    SRCSTRING='export PATH=$PATH:$HOME/.nimble/bin'
    [ ! $(grep -q "$SRCSTRING" $HOME/.bashrc) ] && echo $SRCSTRING >> $HOME/.bashrc
fi


source ~/.bashrc

# fork to support libuuid.so.1
git clone https://github.com/ekarlso/nim-uuid/
cd nim-uuid
nimble install -y

# Install nim_playpen
cd $DIR/..
nimble install -y