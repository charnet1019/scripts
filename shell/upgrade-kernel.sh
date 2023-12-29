#!/usr/bin/env bash

# CentOS 7升级内核

import_repo_key() {
    sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org 2>&1 > /dev/null
}


install_repo() {
    sudo yum install https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm -y  2>&1 > /dev/null
}

install_kernel() {
    sudo yum --enablerepo=elrepo-kernel install kernel-lt.x86_64 -y
}

update_yum_repo() {
sudo cp -f /etc/yum.repos.d/elrepo.repo /etc/yum.repos.d/elrepo.repo.bak
sudo cat > /etc/yum.repos.d/elrepo.repo << 'EOF'
### Name: ELRepo.org Community Enterprise Linux Repository for el7
### URL: https://elrepo.org/

[elrepo]
name=ELRepo.org Community Enterprise Linux Repository - el7
baseurl=http://mirrors.tuna.tsinghua.edu.cn/elrepo/elrepo/el7/$basearch/
	http://mirrors.coreix.net/elrepo/elrepo/el7/$basearch/
	http://mirror.rackspace.com/elrepo/elrepo/el7/$basearch/
	http://linux-mirrors.fnal.gov/linux/elrepo/elrepo/el7/$basearch/
#mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo.el7
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0

[elrepo-testing]
name=ELRepo.org Community Enterprise Linux Testing Repository - el7
baseurl=http://mirrors.tuna.tsinghua.edu.cn/elrepo/testing/el7/$basearch/
	http://mirrors.coreix.net/elrepo/testing/el7/$basearch/
	http://mirror.rackspace.com/elrepo/testing/el7/$basearch/
	http://linux-mirrors.fnal.gov/linux/elrepo/testing/el7/$basearch/
#mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo-testing.el7
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0

[elrepo-kernel]
name=ELRepo.org Community Enterprise Linux Kernel Repository - el7
baseurl=http://mirrors.tuna.tsinghua.edu.cn/elrepo/kernel/el7/$basearch/
	http://mirrors.coreix.net/elrepo/kernel/el7/$basearch/
	http://mirror.rackspace.com/elrepo/kernel/el7/$basearch/
	http://linux-mirrors.fnal.gov/linux/elrepo/kernel/el7/$basearch/
#mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo-kernel.el7
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0

[elrepo-extras]
name=ELRepo.org Community Enterprise Linux Extras Repository - el7
baseurl=http://mirrors.tuna.tsinghua.edu.cn/elrepo/extras/el7/$basearch/
	http://mirrors.coreix.net/elrepo/extras/el7/$basearch/
	http://mirror.rackspace.com/elrepo/extras/el7/$basearch/
	http://linux-mirrors.fnal.gov/linux/elrepo/extras/el7/$basearch/
#mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo-extras.el7
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0
EOF
}


set_grub() {
    sudo grub2-set-default 0
    sudo cp /boot/grub2/grub.cfg /boot/grub2/grub.cfg.bak
    # 非efi模式
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    # efi模式
    #sudo grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
}

riboot() {
    sudo reboot
}


###### main ######
import_repo_key
install_repo
update_yum_repo
install_kernel
set_grub
riboot




