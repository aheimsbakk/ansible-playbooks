# -*- mode: ruby -*-
# vi: set ft=ruby :

CURRENT_PATH = File.dirname(File.expand_path(__FILE__))

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.synced_folder "./", "/vagrant", type: :sshfs, disabled: true

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "6000"
    vb.cpus = 4
    vb.linked_clone = true
    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
    vb.customize ["modifyvm", :id, "--uartmode1", "file", "#{CURRENT_PATH}/console.out"]
  end

  (1..1).each do |n|
    config.vm.define "k3s-m#{n}", primary: n == 1 do |v|
      v.vm.hostname = "k3s-m#{n}"
      v.vm.network "private_network", ip: "10.20.30.#{10 + n}"
    end
    config.vm.provision "ansible-playbook k3s.yml", type: "ansible" do |a|
      a.compatibility_mode = "2.0"
      a.groups = {
        "master_node": [ "k3s-m1" ],
        "worker_node": [ ]
      }
      a.playbook = "homeserver-k3s.yml"
      a.extra_vars = {
        "proxy_address": "#{ENV['PROXY']}",
        "node_ip": "10.20.30.#{10 + n}"
      }
    end
    config.vm.provision "ansible-playbook deployments.yml", type: "ansible", run: "always" do |a|
      a.compatibility_mode = "2.0"
      a.groups = {
        "master_node": [ "k3s-m1" ]
      }
      a.playbook = "deployments.yml"
      a.extra_vars = {
        "node_ip": "10.20.30.#{10 + n}",
        "env": "dev"
      }
    end
  end
end
