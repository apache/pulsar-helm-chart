# -*- mode: ruby -*-
# vi: set ft=ruby :

# vagrant configuration file for setting up local environment for Pulsar Helm Chart 
# CI script development.
#
# usage: 
# Starting vagrant box:
#   vagrant up
# Connecting to vagrant box and running a ci script:
#   vagrant ssh
#   byobu
#   cd /vagrant
#   .ci/chart_test.sh .ci/clusters/values-local-pv.yaml
# Shutting down vagrant box:
#   vagrant halt
# Destroying vagrant box:
#   vagrant destroy
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "7168"
    vb.cpus = 2
  end

  config.vm.provision "shell", inline: <<-SHELL
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get -y install docker.io
    sudo adduser vagrant docker
    echo 'PATH="/vagrant/output/bin:$PATH"' >> /home/vagrant/.profile
  SHELL
end
