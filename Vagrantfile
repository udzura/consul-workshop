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
      sudo yum -y check-update
      sudo yum -y install epel-release
      sudo yum -y install jq nagios-plugins-all
      sudo yum -y install /vagrant/rpms/consul-0.5.2-1.el7.centos.x86_64.rpm || true
    EOS
  end

  config.define_vm :front,  ip: "192.168.100.101", forwarded_port_pairs: {80 => 8080, 8500 => 8500} do |vm|
    vm.provision "step1", type: "shell" do |s|
      s.inline = indent(<<-EOS)
        set -x
        echo '{"server": true, "bind_addr": "192.168.100.101", "client_addr": "0.0.0.0", "bootstrap_expect": 3}' | sudo tee /etc/consul/default.json
        sudo yum -y install /vagrant/rpms/consul-ui-0.5.2-1.el7.centos.x86_64.rpm
        sudo yum -y install /vagrant/rpms/consul-template-0.10.0-1.el7.centos.x86_64.rpm
        sudo systemctl restart consul
        sleep 5
        sudo journalctl -u consul -e -n 20
      EOS
    end

    vm.provision "step3", type: "shell" do |s|
      s.inline = indent(<<-EOS)
        set -x
        sudo yum -y install nginx

        cat <<JSON | sudo tee /etc/consul/step3-check-nginx.json
        {
          "service": {
            "id": "nginx",
            "name": "nginx",
            "port": 80,
            "check": {
              "script": "/usr/lib64/nagios/plugins/check_http -H localhost",
              "interval": "30s"
            }
          }
        }
        JSON
        sudo systemctl reload consul
        sleep 2
        sudo journalctl -u consul -e -n 20
      EOS
    end

    vm.provision "step4", type: "shell" do |s|
      s.inline = indent(<<-EOS)
        set -x
        sudo systemctl restart nginx
      EOS
    end

    vm.provision "step6", type: "shell" do |s|
      s.inline = indent(<<-EOS)
        set -x
        sudo ruby -i -e 'print ARGF.read.sub(/listen +80/, "listen 10080")' /etc/nginx/nginx.conf
        cat <<TEMPLATE | sudo tee /usr/local/sample.conf.ctmpl
        upstream backend_apps {
        {{range service "production.application@dc1" "passing"}}
            server {{.Address}}:{{.Port}};{{end}}
        }

        server {
            listen      80;
            server_name _;

            proxy_set_header Host               \\$host;
            proxy_set_header X-Real-IP          \\$remote_addr;
            proxy_set_header X-Forwarded-For    \\$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Host   \\$host;
            proxy_set_header X-Forwarded-Server \\$host;

            location / {
                proxy_pass http://backend_apps;
            }

        }
        TEMPLATE

        cat <<HCL | sudo tee /etc/consul-template/consul-template.hcl
        consul = "127.0.0.1:8500"
        retry = "10s"
        max_stale = "10m"
        log_level = "info"
        pid_file = "/var/run/consul-template.pid"

        template {
          source = "/usr/local/sample.conf.ctmpl"
          destination = "/etc/nginx/conf.d/sample.conf"
          command = "systemctl reload nginx"
        }
        HCL

        sudo systemctl restart consul-template
        sleep 2
        sudo journalctl -u consul-template -e -n 20
      EOS
    end

  end

  [1, 2, 3].each do |num|
    each_ip = "192.168.100.%d" % (110 + num)
    config.define_vm ("back%02d" % num), ip: each_ip, forwarded_port_pairs: {3000 => 3000 + num} do |vm|
      vm.provision "step2", type: "shell" do |s|
        s.inline = indent(<<-EOS)
          set -x
          echo '{"server": true, "bind_addr": "#{each_ip}"}' | sudo tee /etc/consul/default.json
          sudo systemctl restart consul
          sleep 1
          consul join 192.168.100.101
          sleep 5
          sudo journalctl -u consul -e -n 20
        EOS
      end

      vm.provision "step5", type: "shell" do |s|
        s.inline = indent(<<-EOS)
          set -x
          sudo yum -y install rubygem-rack

          cat <<RUBY | sudo tee /usr/local/app.ru
          require "socket"
          run lambda{|e| [200, {'Content-Type'=>'text/plain'}, ["OK: response from " + Socket.gethostname]] }
          RUBY
          cat <<UNIT | sudo tee /etc/systemd/system/ruby-app.service

          [Unit]
          Description=Ruby rack app
          After=network.target
          Requires=network.target

          [Service]
          Type=simple
          ExecStart=/usr/bin/rackup -p 3000 /usr/local/app.ru

          [Install]
          WantedBy=multi-user.target
          UNIT
          systemctl enable ruby-app.service
          systemctl start ruby-app.service

          cat <<JSON | sudo tee /etc/consul/step5-check-application.json
          {
            "service": {
              "id": "application",
              "name": "application",
              "port": 3000,
              "check": {
                "script": "/usr/lib64/nagios/plugins/check_http -H localhost -p 3000",
                "interval": "30s"
              }
            }
          }
          JSON
          sudo systemctl reload consul
          sleep 2
          sudo journalctl -u consul -u ruby-app -e -n 40
        EOS
      end

      vm.provision "step6", type: "shell" do |s|
        s.inline = indent(<<-EOS)
          set -x
          cat <<JSON | sudo tee /etc/consul/step5-check-application.json
          {
            "service": {
              "id": "application",
              "name": "application",
              "port": 3000,
              "tags": ["production"],
              "check": {
                "script": "/usr/lib64/nagios/plugins/check_http -H localhost -p 3000",
                "interval": "30s"
              }
            }
          }
          JSON
          sudo systemctl reload consul
          sleep 2
          sudo journalctl -u consul -e -n 20
        EOS
      end

      vm.provision "step7", type: "shell" do |s|
        s.inline = indent(<<-EOS)
          set -x
          sudo kill -9 $(pgrep rackup)
        EOS
      end
    end
  end
end
