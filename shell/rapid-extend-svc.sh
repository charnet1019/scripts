#!/bin/bash


# 已存在生产服务器
IP="172.18.4.5"
USERNAME="root"
PASSWORD='xxxxxxxxxxxxxxxxxx'

gitlab_user="user"
gitlab_pwd="xxxxxxxxxxxxxxxxx"

# 服务编排url
orch_gitlab_url="http://${gitlab_user}:${gitlab_pwd}@172.18.10.13:10000/exy/dockercompose.git"



# 生产环境服务编排临时存储路径
orch_prod="/tmp/dockercompose/prod"
base_path="/opt/exueyun"

DATETIME='date "+%F %T"'

success() {
    printf "\r$(eval $DATETIME) [ \033[00;32mINFO\033[0m ]%s\n" "$1"
}

warn() {
    printf "\r$(eval $DATETIME) [\033[0;33mWARNING\033[0m]%s\n" "$1"
}

fail() {
    printf "\r$(eval $DATETIME) [ \033[0;31mERROR\033[0m ]%s\n" "$1"
}

usage() {
    echo "Usage: ${0##*/} {info|warn|err} MSG"
}

log() {
    if [ $# -lt 2 ]; then
        log err "Not enough arguments [$#] to log."
    fi

    __LOG_PRIO="$1"
    shift
    __LOG_MSG="$*"

    case "${__LOG_PRIO}" in
        crit) __LOG_PRIO="CRIT";;
        err) __LOG_PRIO="ERROR";;
        warn) __LOG_PRIO="WARNING";;
        info) __LOG_PRIO="INFO";;
        debug) __LOG_PRIO="DEBUG";;
    esac

    if [ "${__LOG_PRIO}" = "INFO" ]; then
        success " $__LOG_MSG"
    elif [ "${__LOG_PRIO}" = "WARNING" ]; then
        warn " $__LOG_MSG"
    elif [ "${__LOG_PRIO}" = "ERROR" ]; then
        fail " $__LOG_MSG"
    else
       usage
    fi
}



set_yum_source() {
    [ ! -d /etc/yum.repos.d/bak ] && mkdir /etc/yum.repos.d/bak
    #mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
    mv /etc/yum.repos.d/CentOS-* /etc/yum.repos.d/bak
    #wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

    cat > /etc/yum.repos.d/tsinghua.repo <<- 'EOF'
[base]
name=CentOS-$releasever - Base
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/os/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-$releasever - Updates
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/updates/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/extras/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/centosplus/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
}

disable_secure() {
    # disable selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    # disable firewalld
    systemctl stop firewalld.service && systemctl disable firewalld.service && systemctl status firewalld.service
}

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

install_expect() {
    yum -y install expect &> /dev/null
}

check_expect() {
    if ! command_exists expect; then
        log warn "No expect command and try to install, please wait..."
        install_expect
        if ! command_exists expect; then
            log err "Installation failed, please install the expect command manually."
            exit 1
        else
            log info "Installation successed."
        fi
    fi
}

set_kernel_paras() {
    cat >> /etc/sysctl.conf <<- EOF
fs.file-max=1000000
net.core.somaxconn = 65535
vm.swappiness=0
kernel.pid_max=1000000
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.conf.all.rp_filter=1
EOF
}

set_fd_limits() {
    modprobe br_netfilter
    echo "* soft nproc 65536" >> /etc/security/limits.conf
    echo "* hard nproc 65536" >> /etc/security/limits.conf
    echo "* soft nofile 65536" >> /etc/security/limits.conf
    echo "* hard nofile 65536" >> /etc/security/limits.conf
    echo "* soft memlock unlimited" >> /etc/security/limits.conf
    echo "* hard memlock unlimited" >> /etc/security/limits.conf
}

update_os() {
    sudo yum -y update
    sudo yum install -y net-tools wget vim tcpdump lsof bind-utils yum-utils
}

add_docker_yum_src() {
    sudo yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum makecache fast
}

install_git() {
    yum -y install git
    #yum -y install https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm
    #yum -y upgrade git
}

pull_orchestration() {
    cd /tmp
    [ -d /tmp/dockercompose ] && rm -rf /tmp/dockercompose
    git clone ${orch_gitlab_url}
}


install_qxy_svc() {
    echo
    echo "++++++++++++++++++++ 准备安装后端服务 +++++++++++++++++++++"
    echo
    echo "请选择要安装的服务: "
    echo " 1) gateway"
    echo " 2) base-service"
    echo " 3) es-service"
    echo " 4) hardware-service"
    echo " 5) client-consumer"
    echo " 6) boss-consumer"
    echo " 7) im"
    echo " 8) push"
    echo " 9) school"
    echo " 10) service-wechat"
    echo " 11) exit"
    echo
    read -p "Option: " option
    until [[ "$option" =~ ^([0-9]|1[0-1]{1,})$ ]]; do
        echo "$option: invalid selection."
        read -p "Option: " option
    done

    case "$option" in
        1)
            [ ! -d ${base_path}/gateway ] && mkdir -p ${base_path}/gateway
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/gateway/gateway.yml ${base_path}/gateway
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/gateway/gateway.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        2)
            [ ! -d ${base_path}/base-service ] && mkdir -p ${base_path}/base-service
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/base-service/base-service.yml ${base_path}/base-service
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/base-service/base-service.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        3)
            [ ! -d ${base_path}/es-service ] && mkdir -p ${base_path}/es-service
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/es-service/es-service.yml ${base_path}/es-service
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/es-service/es-service.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        4)
            [ ! -d ${base_path}/hardware-service ] && mkdir -p ${base_path}/hardware-service
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/hardware-service/hardware-service.yml ${base_path}/hardware-service
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/hardware-service/hardware-service.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        5)
            [ ! -d ${base_path}/client-consumer ] && mkdir -p ${base_path}/client-consumer
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/client-consumer/client-consumer.yml ${base_path}/client-consumer
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/client-consumer/client-consumer.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        6)
            [ ! -d ${base_path}/boss-consumer ] && mkdir -p ${base_path}/boss-consumer
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/boss-consumer/boss-consumer.yml ${base_path}/boss-consumer
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/boss-consumer/boss-consumer.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        7)
            [ ! -d ${base_path}/im ] && mkdir -p ${base_path}/im
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/im/im.yml ${base_path}/im
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/im/im.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        8)
            [ ! -d ${base_path}/push ] && mkdir -p ${base_path}/push
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/push/push.yml ${base_path}/push
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/push/push.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        9)
            [ ! -d ${base_path}/school ] && mkdir -p ${base_path}/school
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/school/school.yml ${base_path}/school
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/school/school.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        10)
            [ ! -d ${base_path}/service-wechat ] && mkdir -p ${base_path}/service-wechat
            expect -c  <<- EOF &> /dev/null "
                spawn /usr/bin/scp $USERNAME@$IP:${base_path}/service-wechat/service-wechat.yml ${base_path}/service-wechat
                expect {
                    \"(yes/no)?\" {
                        send \"yes\r\"
                        expect {
                            "*assword" {
                                send \"$PASSWORD\r\"
                            }
                        }
                    }
                    "*assword*" {
                        send \"$PASSWORD\r\"
                    }
                    expect "100%"
                    expect eof    
                }
                catch wait retVal
                exit [lindex \$retVal 3]"
EOF
            if [ $? -eq 0 ]; then
                log info "服务编排复制成功"
            else
                log err "服务编排复制失败"
            fi

            docker-compose -f ${base_path}/service-wechat/service-wechat.yml up -d
            if [ $? -eq 0 ]; then
                log info "服务启动成功"
            else
                log err "服务启动失败"
            fi
            install_qxy_svc
            ;;
        11)
            exit
            ;;
    esac
}

install_docker() {
    sudo yum -y install docker-ce-20.10.5
}

install_docker_compose() {
   curl -L http://172.18.10.13:58848/software/docker/docker-compose -o /usr/local/bin/docker-compose 
   chmod +x /usr/local/bin/docker-compose
}

set_docker_registry() {
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],"insecure-registries":["172.18.10.13:10080"],"log-driver":"json-file","log-opts": {"max-size":"500m", "max-file":"3"}
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

set_registry_auth() {
    [ ! -d /root/.docker ] && mkdir /root/.docker
    cat >> /root/.docker/config.json <<- EOF
{
    "auths": {
    	"172.18.10.13:10080": {
    		"auth": "xxxxxxxxxxxxxxxxxxxxxx"
    	}
    }
}
EOF
}


if [ "$#" != "1" ]; then
    echo "Usage: 必须传其中一个参数: [--init | --svc]"
    exit 0
fi

if [ "$1" == "--init" ]; then
    echo "初始化系统"
    update_os
    ## 系统更新完成后重启
    reboot
elif [ "$1" == "--svc" ]; then
    add_docker_yum_src
    install_docker
    install_docker_compose
    set_docker_registry
    start_docker
    set_registry_auth
    check_expect
    #install_git
    #pull_orchestration
    install_qxy_svc
else
    log info "未知参数"
    exit 1
fi







