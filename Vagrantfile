# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
bash /opt/play/bin/bootstrap.sh

sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
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
