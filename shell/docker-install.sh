#!/usr/bin/env bash

DOCKER_VERSION="20.10.6"


# 检测云平台类型
cloud_platform_type=""
if sudo dmidecode | grep -qw "Tencent Cloud"; then
    cloud_platform_type="qcloud"
elif sudo dmidecode | grep -qw "Aliyun"; then
    cloud_platform_type="aliyun"
elif sudo dmidecode | grep -qw "VMware"; then
    cloud_platform_type="vmware"
elif sudo dmidecode | grep -qw "OpenStack"; then
    # 也可能是华为云
    cloud_platform_type="openstack"
elif sudo dmidecode | grep -qw "Dell"; then
    # 可以认为是物理服务器
    cloud_platform_type="physical"
fi

# 检测OS类型
if grep -qs "ubuntu" /etc/os-release; then
    os="ubuntu"
    os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    group_name="nogroup"
elif [[ -e /etc/debian_version ]]; then
    os="debian"
    os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
    group_name="nogroup"
elif [[ -e /etc/centos-release ]]; then
    os="centos"
    os_version=$(grep -oE '[0-9]+' /etc/centos-release | head -1)
    group_name="nobody"
elif [[ -e /etc/fedora-release ]]; then
    os="fedora"
    os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
    group_name="nobody"
else
    echo "仅支持以下系统 Ubuntu, Debian, CentOS, and Fedora."
    exit
fi


if [[ "$os" == "ubuntu" && "$os_version" -lt 1804 ]]; then
    echo "仅支持Ubuntu 18.04及以上版本"
    exit
fi

if [[ "$os" == "debian" && "$os_version" -lt 9 ]]; then
    echo "仅支持Debian 9及以上版本."
    exit
fi

if [[ "$os" == "centos" && "$os_version" -lt 7 ]]; then
    echo "仅支持CentOS 7及以上版本"
    exit
fi


# Detect environments where $PATH does not include the sbin directories
#if ! grep -q sbin <<< "$PATH"; then
#	echo '$PATH does not include sbin. Try using "su -" instead of "su".'
#	exit
#fi

disable_secure() {
    # disable selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
    # disable firewalld
    systemctl stop firewalld.service && systemctl disable firewalld.service && systemctl status firewalld.service
}

set_kernel_params() {
    cat >> /etc/sysctl.d/docker.conf<<- EOF
fs.file-max=1000000
net.core.somaxconn = 65535
vm.swappiness=0
kernel.pid_max=1000000
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.conf.all.rp_filter=1
EOF

    modprobe br_netfilter
    sysctl -p
}

# ****************** debian/ubuntu ********************
# 卸载debian/ubuntu中已安装的docker
remove_old_docker_for_debian_or_ubuntu() {
    sudo apt-get remove docker docker-engine docker.io 
}

# 安装依赖
install_depens_for_debian_or_ubuntu() {
    sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common
}


# 设置debian amd64 apt源
add_docker_sourcelist_for_debian() {
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    sudo add-apt-repository \
   "deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian \
   $(lsb_release -cs) \
   stable" 
}

# 设置debian 树莓派或其它ARM架构apt源
add_docker_sourcelist_for_debian_arm() {
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    echo "deb [arch=armhf] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian \
     $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list
}

# 设置ubuntu amd64 apt源
add_docker_sourcelist_for_ubuntu() {
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository \
   "deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
}

# 设置ubuntu 树莓派或其它ARM架构apt源
add_docker_sourcelist_for_ubuntu_arm() {
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    echo "deb [arch=armhf] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
     $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list
}

# debian/ubuntu安装docker
install_docker_for_debian_or_ubuntu() {
    sudo apt-get update
    #sudo apt-get install docker-ce
    sudo apt-get install docker-ce=${DOCKER_VERSION}
}


# ****************** defora/centos/rhel ********************
# 删除已安装的docker
remove_old_docker_for_rhel_distro() {
    sudo yum remove docker docker-common docker-selinux docker-engine
}

# 安装依赖
install_depens_for_rhel_distro() {
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2 wget
}

# 设置centos和rhel yum源
add_docker_repo_for_centos_or_rhel() {
    wget -O /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo sed -i 's+download.docker.com+mirrors.tuna.tsinghua.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo
}

# 设置fedora yum源
add_docker_repo_for_defora() {
    wget -O /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo sed -i 's+download.docker.com+mirrors.tuna.tsinghua.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo
}


# fefora/rhel/centos安装docker
install_docker_for_rhel_distro() {
    sudo yum makecache fast
    #sudo yum install docker-ce
    sudo yum -y install docker-ce-${DOCKER_VERSION}
}


# ******** registry *********
set_docker_registry_for_qcloud() {
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],"insecure-registries":["0.0.0.0/0"],"log-driver":"json-file","log-opts": {"max-size":"500m", "max-file":"3"}
}
EOF
}

set_docker_registry_for_aliyun() {
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://obou6wyb.mirror.aliyuncs.com"],"insecure-registries":["0.0.0.0/0"],"log-driver":"json-file","log-opts": {"max-size":"500m", "max-file":"3"}
}
EOF
}


start_docker() {
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo systemctl status docker
    sudo groupadd docker
    sudo gpasswd -a ${USER} docker
    sudo systemctl restart docker
}


# ###### entrypoint #######
if [[ "${cloud_platform_type}" == "qcloud" && "${os}" == "ubuntu" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_debian_or_ubuntu
    install_depens_for_debian_or_ubuntu
    add_docker_sourcelist_for_ubuntu
    install_docker_for_debian_or_ubuntu
    set_docker_registry_for_qcloud
    start_docker
elif [[ "${cloud_platform_type}" == "qcloud" && "${os}" == "debian" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_debian_or_ubuntu
    install_depens_for_debian_or_ubuntu
    add_docker_sourcelist_for_debian
    install_docker_for_debian_or_ubuntu
    set_docker_registry_for_qcloud
    start_docker
elif [[ "${cloud_platform_type}" == "qcloud" && "${os}" == "centos" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_rhel_distro
    install_depens_for_rhel_distro
    add_docker_repo_for_centos_or_rhel
    install_docker_for_rhel_distro
    set_docker_registry_for_qcloud
    start_docker
elif [[ "${cloud_platform_type}" == "qcloud" && "${os}" == "fedora" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_rhel_distro
    install_depens_for_rhel_distro
    add_docker_repo_for_defora
    install_docker_for_rhel_distro
    set_docker_registry_for_qcloud
    start_docker
elif [[ "${cloud_platform_type}" == "aliyun" && "${os}" == "ubuntu" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_debian_or_ubuntu
    install_depens_for_debian_or_ubuntu
    add_docker_sourcelist_for_ubuntu
    install_docker_for_debian_or_ubuntu
    set_docker_registry_for_aliyun
    start_docker
elif [[ "${cloud_platform_type}" == "aliyun" && "${os}" == "debian" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_debian_or_ubuntu
    install_depens_for_debian_or_ubuntu
    add_docker_sourcelist_for_debian
    install_docker_for_debian_or_ubuntu
    set_docker_registry_for_aliyun
    start_docker
elif [[ "${cloud_platform_type}" == "aliyun" && "${os}" == "centos" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_rhel_distro
    install_depens_for_rhel_distro
    add_docker_repo_for_centos_or_rhel
    install_docker_for_rhel_distro
    set_docker_registry_for_aliyun
    start_docker
elif [[ "${cloud_platform_type}" == "aliyun" && "${os}" == "fedora" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_rhel_distro
    install_depens_for_rhel_distro
    add_docker_repo_for_defora
    install_docker_for_rhel_distro
    set_docker_registry_for_aliyun
    start_docker
elif [[ "${cloud_platform_type}" == "vmware" || "${cloud_platform_type}" == "openstack" || "${cloud_platform_type}" == "physical" && "${os}" == "ubuntu" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_debian_or_ubuntu
    install_depens_for_debian_or_ubuntu
    add_docker_sourcelist_for_ubuntu
    install_docker_for_debian_or_ubuntu
    set_docker_registry_for_aliyun
    start_docker
elif [[ "${cloud_platform_type}" == "vmware" || "${cloud_platform_type}" == "openstack" || "${cloud_platform_type}" == "physical" && "${os}" == "debian" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_debian_or_ubuntu
    install_depens_for_debian_or_ubuntu
    add_docker_sourcelist_for_debian
    install_docker_for_debian_or_ubuntu
    set_docker_registry_for_aliyun
    start_docker
elif [[ "${cloud_platform_type}" == "vmware" || "${cloud_platform_type}" == "openstack" || "${cloud_platform_type}" == "physical" && "${os}" == "centos" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_rhel_distro
    install_depens_for_rhel_distro
    add_docker_repo_for_centos_or_rhel
    install_docker_for_rhel_distro
    set_docker_registry_for_aliyun
    start_docker
elif [[ "${cloud_platform_type}" == "vmware" || "${cloud_platform_type}" == "openstack" || "${cloud_platform_type}" == "physical" && "${os}" == "fedora" ]]; then
    disable_secure
    set_kernel_params
    remove_old_docker_for_rhel_distro
    install_depens_for_rhel_distro
    add_docker_repo_for_defora
    install_docker_for_rhel_distro
    set_docker_registry_for_aliyun
    start_docker
fi




