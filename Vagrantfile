# -*- mode: ruby -*-
# vi: set ft=ruby :

# export ANSIBLE_INJECT_FACT_VARS=False

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/impish64"
  config.vm.box_check_update = false

  # config.vm.network "forwarded_port", guest: 80, host: 8080
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
  config.vm.network "private_network", ip: "10.10.10.10"

  # config.vm.network "public_network"
  # config.vm.synced_folder "../data", "/vagrant_data"

  config.vm.provider "virtualbox" do |l|
    #l.qemu_use_session = false
    l.memory = "4096"
    l.cpus = "4"
  end

  config.vm.define "vagrant" do |config|
    config.vm.hostname = "vagrant"
  end

  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL

  config.vm.provision "ansible-playbook --check --diff", run: "always", type: "ansible" do |a|
    a.compatibility_mode = "2.0"
    a.groups = {
      "podman" => [ "vagrant" ]
    }
    a.limit = "all"
    a.playbook = "podman.yml"
    a.raw_arguments = ["--check", "--diff"]
  end

  config.vm.provision "ansible-playbook", type: "ansible" do |a|
    a.compatibility_mode = "2.0"
    a.groups = {
      "podman" => [ "vagrant" ]
    }
    a.limit = "all"
    a.playbook = "podman.yml"
  end
end
