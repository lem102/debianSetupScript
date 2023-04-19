# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"
  # config.vm.box = "hashicorp/bionic64"

  config.vagrant.plugins = {
    "vagrant-vbguest" => {"version" => "0.31.0"},
    "vagrant-env" => {"version" => "0.0.3"}
  }

  config.env.enable

  config.vm.provision :shell,
                      path: "bootstrap.sh",
                      env: {
                        "PASSWORD" => ENV["PASSWORD"],
                        "GITHUB_TOKEN" => ENV["GITHUB_TOKEN"],
                        "EMAIL" => ENV["EMAIL"]
                      }

  config.vbguest.auto_update = true

  config.vm.provider "virtualbox" do |vb|
    vb.gui = true
    vb.memory = "8192"
    vb.customize ["modifyvm", :id, "--vram", "24"]
    vb.customize ["modifyvm", :id, "--audio", "default"]
  end
end

