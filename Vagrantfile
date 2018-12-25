Vagrant.require_version ">= 2.2.0"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"

  config.vm.network "forwarded_port", guest: 5601, host: 5601

  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--uartmode1", "disconnected"]
    v.memory = 4096
  end

  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "provisioning/playbook.yml"
  end
end
