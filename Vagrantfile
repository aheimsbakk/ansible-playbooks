# -*- mode: ruby -*-
# vi: set ft=ruby :

CURRENT_PATH = File.dirname(File.expand_path(__FILE__))

Vagrant.configure("2") do |config|
  k3s_master = [ "k3s-m1" ]
  k3s_agents = [ "k3s-a1", "k3s-a2" ]
  nodes = k3s_master + k3s_agents

  last_octet = 10
  octet = last_octet

  nodes.each do |node|
    config.vm.define "#{node}", primary: node == nodes.first do |config|
      config.vm.hostname = "#{node}"
      config.vm.network "private_network", autostart: true, ip: "10.20.30.#{octet+=1}"
      config.vm.box = "debian/bullseye64"
      config.vm.synced_folder "./", "/vagrant", type: :sshfs, disabled: true

      config.vm.provider "libvirt" do |l|
        l.cpus = 1
        l.memory = "2560"
        l.qemu_use_session = false
        l.autostart = true
        l.management_network_autostart = true
      end

      if node == nodes.last
        config.vm.provision "ansible-playbook k3s.yml", type: "ansible" do |a|
          octet = last_octet
          host_vars = {}
          nodes.each do |n|
            host_vars[n] = { "node_ip": "10.20.30.#{octet+=1}",
                             "k3s_opts": "--flannel-iface eth1",
                             "env": "dev" }
          end

          a.compatibility_mode = "2.0"
          a.host_vars = host_vars
          a.groups = {
            "k3s_master" => k3s_master,
            "k3s_agents" => k3s_agents
          }
          a.limit = "all"
          a.playbook = "k3s.yml"
        end
        config.vm.provision "ansible-playbook deployments.yml", type: "ansible", run: "always" do |a|
          a.compatibility_mode = "2.0"
          a.groups = { "k3s_master": k3s_master,
                       "k3s_master:vars": { "env": "dev" } }
          a.limit = "all"
          a.playbook = "deployments.yml"
        end
      end
    end
  end
end
