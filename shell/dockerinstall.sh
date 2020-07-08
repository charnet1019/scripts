#!/bin/sh

# disable selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# disable firewalld
#systemctl stop firewalld
#systemctl disable firewalld


set_img_mirror() {
    [ ! -d /etc/docker ] && mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors" : [
        "https://obou6wyb.mirror.aliyuncs.com"
    ],
    "debug" : true,
    "experimental" : true
}
EOF
}


#移除旧版本docker
yum -y remove docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-selinux \
    docker-engine-selinux \
    docker-engine

#安装一些必要的系统工具
#yum install -y yum-utils device-mapper-persistent-data lvm2
yum install -y yum-utils

#添加软件源信息
status_code=$(curl --connect-timeout 3 -X GET -I -o /dev/null -s -w %{http_code} https://www.google.com)
if [ ${status_code} -ne 200 ]; then
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
else
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
fi

#更新 yum 缓存
yum makecache fast

#安装 Docker-ce
yum -y install docker-ce-19.03.5-3.el7

#启动 Docker 后台服务
systemctl start docker

#docker加入开机自启动
systemctl enable docker


if [ ${status_code} -ne 200 ]; then
    set_img_mirror
fi

systemctl daemon-reload
systemctl restart docker

#下载docket-compose
curl -L https://github.com/docker/compose/releases/download/1.25.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose

#修改权限
chmod +x /usr/local/bin/docker-compose
