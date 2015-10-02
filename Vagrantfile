# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|
  #
  # Define VM by a boiler template
  #
  def config.define_vm(name, ip: nil, forwarded_port_pairs: {}, memory: 512, cpus: 2, &blk)
    self.vm.define name do |c|
      c.vm.provider :virtualbox do |vbox|
        vbox.name = "vagrant-#{name}-workshop"

        vbox.customize ["modifyvm", :id, "--ioapic", "on"]
        vbox.customize ["modifyvm", :id, "--memory", memory]
        vbox.customize ["modifyvm", :id, "--cpus",   cpus]
      end
      c.vm.hostname = "#{name.to_s.tr('_', '-')}.workshop.example"

      forwarded_port_pairs.each_pair do |k, v|
        c.vm.network :forwarded_port, guest: k, host: v
      end
      c.vm.network :private_network, ip: ip

      blk.call(c) if blk
    end
  end

  config.vm.box = "puppetlabs/centos-7.0-64-puppet"
  config.vm.provider :virtualbox do |vbox|
    vbox.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
    vbox.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]
  end

  config.define_vm :front,  ip: "192.168.100.101", forwarded_port_pairs: {80 => 8080, 8500 => 8500}
  config.define_vm :back01, ip: "192.168.100.111", forwarded_port_pairs: {3000 => 3000}
  config.define_vm :back02, ip: "192.168.100.112", forwarded_port_pairs: {3000 => 3000}
  config.define_vm :back03, ip: "192.168.100.113", forwarded_port_pairs: {3000 => 3000}

end
