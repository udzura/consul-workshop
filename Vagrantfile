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

        vbox.customize ["modifyvm", :id, "--nic2", "intnet"]
        vbox.customize ["modifyvm", :id, "--intnet2", "internal_network"]
      end
      c.vm.hostname = "#{name.to_s.tr('_', '-')}.workshop.example"

      forwarded_port_pairs.each_pair do |k, v|
        c.vm.network :forwarded_port, guest: k, host: v
      end
      c.vm.network :private_network, ip: ip

      blk.call(c.vm) if blk
    end
  end

  def indent(s)
    ind = s.lines.first.scan(/^ +/)[0]
    s.gsub(/^#{ind}/m, '')
  end

  config.vm.box = "puppetlabs/centos-7.0-64-puppet"
  config.vm.provider :virtualbox do |vbox|
    vbox.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
    vbox.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]
  end

  config.vm.provision "step0", type: "shell" do |s|
    s.inline = indent(<<-EOS)
      set -x
      sudo iptables -F
      sudo yum -y update-cache
      sudo yum -y install epel-release
      sudo yum -y install jq
      sudo yum -y install /vagrant/rpms/consul-0.5.2-1.el7.centos.x86_64.rpm || true
    EOS
  end

  config.define_vm :front,  ip: "192.168.100.101", forwarded_port_pairs: {80 => 8080, 8500 => 8500} do |vm|
    vm.provision "step1", type: "shell" do |s|
      s.inline = indent(<<-EOS)
        set -x
        echo '{"server": true, "bind_addr": "192.168.100.101", "bootstrap_expect": 3}' | sudo tee /etc/consul/default.json
        sudo yum -y install /vagrant/rpms/consul-ui-0.5.2-1.el7.centos.x86_64.rpm
        sudo yum -y install /vagrant/rpms/consul-template-0.10.0-1.el7.centos.x86_64.rpm
        sudo systemctl restart consul
        sleep 5
        sudo journalctl -u consul -e -n 20
      EOS
    end
  end

  [1, 2, 3].each do |num|
    each_ip = "192.168.100.%d" % (110 + num)
    config.define_vm ("back%02d" % num), ip: each_ip, forwarded_port_pairs: {3000 => 3000 + num} do |vm|
      vm.provision "step2", type: "shell" do |s|
        s.inline = indent(<<-EOS)
          set -x
          sudo yum -y install /vagrant/rpms/consul-0.5.2-1.el7.centos.x86_64.rpm
          echo '{"server": true, "bind_addr": "#{each_ip}"}' | sudo tee /etc/consul/default.json
          sudo systemctl restart consul
          sleep 1
          consul join 192.168.100.101
          sleep 5
          sudo journalctl -u consul -e -n 20
        EOS
      end
    end
  end

end
