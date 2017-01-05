# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"

  config.vm.synced_folder "./", "/home/vagrant/novatools"

  # Enable USB and attach Novatouch in bootloader mode to the VM
  config.vm.provider "virtualbox" do |vb|
       vb.customize ['modifyvm', :id, '--usb', 'on']
       vb.customize ['usbfilter', 'add', '0', '--target', :id, '--name', 'USB HID device', '--vendorid', '0x2047', '--productid', '0x0200']
  end

  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y make gcc-msp430 libhidapi-hidraw0 mspdebug python-pip bzr linux-image-extra-$(uname -r)

    # udev rule to be able to access /dev/hidraw0 as vagrant user
    cp novatools/99-hidraw.rules /etc/udev/rules.d
    udevadm control --reload-rules ; udevadm trigger

    # python-msp430-tools upstream package is broken.. install directly from bzr repo
    # https://bugs.launchpad.net/python-msp430-tools/+bug/936695
    pip install -e bzr+lp:python-msp430-tools#egg=python-msp430-tools

    # cleanup
    apt-get -y autoremove
  SHELL
end
