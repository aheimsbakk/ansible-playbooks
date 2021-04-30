# -*- mode: ruby -*-
# vi: set ft=ruby :

CURRENT_PATH = File.dirname(File.expand_path(__FILE__))

Vagrant.configure("2") do |config|
  master_nodes = [ "k3s-m1" ]
  worker_nodes = [ "k3s-w1", "k3s-w2" ]
  nodes = worker_nodes + master_nodes

  last_octet = 10
  octet = last_octet

  nodes.each do |node|
    config.vm.define "#{node}", primary: node == nodes.last do |config|
      config.vm.hostname = "#{node}"
      config.vm.network "private_network", ip: "10.20.30.#{octet+=1}"
      config.vm.box = "ubuntu/focal64"
      config.vm.synced_folder "./", "/vagrant", type: :sshfs, disabled: true

      config.vm.provider "virtualbox" do |vb|
        vb.memory = "2000"
        vb.cpus = 2
        vb.linked_clone = true
      end

      if node == nodes.last
        config.vm.provision "ansible-playbook k3s.yml", type: "ansible" do |a|
          octet = last_octet
          host_vars = {}
          nodes.each do |n|
            host_vars[n] = { "node_ip": "10.20.30.#{octet+=1}", "env": "dev" }
          end

          a.compatibility_mode = "2.0"
          a.limit = "all"
          a.playbook = "homeserver-k3s.yml"
          a.host_vars = host_vars
          a.groups = {
            "master_node" => master_nodes,
            "worker_node" => worker_nodes
          }
        end
        config.vm.provision "ansible-playbook deployments.yml", type: "ansible", run: "always" do |a|
          a.groups = {
            "master_node": node,
          }
          a.host_vars = {
            node => { "env" => "dev" }
          }
          a.playbook = "deployments.yml"
        end
      end
    end
  end
end
