#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

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
