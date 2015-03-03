# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
sudo yum install -y
    git \
    gcc \
    make \
    wget \
    clang \
    glib2-devel \
    glibc-devel \
    libseccomp-devel \
    systemd-devel

sudo wget https://raw.githubusercontent.com/ekarlso/nim-vm/master/bin/nim-vm -O /bin/nim-vm
sudo chmod +x /bin/nim-vm
sudo nim-vm -d /opt/nim -b /bin install devel
sudo nim-vm -d /opt/nim -b /bin use devel
sudo chmod +x /bin/nim

[ ! -d "nimble" ] && git clone https://github.com/nim-lang/nimble
cd nimble
nim c -r src/nimble install
SRCSTRING='export PATH=$PATH:$HOME/.nimble/bin'
[ ! -z "$(grep -q "$SRCSTRING" $HOME/.bashrc)" ] && echo "$SRCSTRING" >> $HOME/.bashrc
source ~/.bashrc

sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --reload

cd /opt/play
#nimble install -y
#nim c src/nim_play.nim
SCRIPT

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
 config.vm.box = "hansode/fedora-21-server-x86_64"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "private_network", ip: "192.168.27.120"

  config.vm.synced_folder ".", "/opt/play"

  config.vm.provision :shell, :privileged => false, :inline => $script
end
