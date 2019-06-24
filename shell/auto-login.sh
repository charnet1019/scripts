#!/bin/bash
##########################################################
#
# Copyright (2017-10-21, )
#
# Author: charnet1019@163.com
# Last modified: 2017-10-22 00:02
# Description: 实现ssh免密登录
# 
# Tips: ssh服务端需设置如下参数解决连接慢拷贝失败的问题 
# IgnoreRhosts yes 
# GSSAPIAuthentication no 
# UseDNS no
#
##########################################################

# definition IP dictionary array
declare -A IPListDict

USER_NAME="root"

# 主机IP地址和密码，每行一个主机
IPListDict=(
[192.168.2.3:22]="secret"
[192.168.2.4:22018]="secret"
)

# for ssh
ssh_keygen="/usr/bin/ssh-keygen"
ssh_key_type="rsa"
ssh_pwd=''
ssh_key_base_dir=~/.ssh
ssh_pri_key=$ssh_key_base_dir/id_rsa
ssh_pub_key=$ssh_key_base_dir/id_rsa.pub
ssh_known_hosts=$ssh_key_base_dir/known_hosts
ssh_copy_id="/usr/bin/ssh-copy-id"

DATETIME=`date "+%F %T"`

success() {
    printf "\r$DATETIME [ \033[00;32mINFO\033[0m ]%s\n" "$1"
}

warn() {
    printf "\r$DATETIME [\033[0;33mWARNING\033[0m]%s\n" "$1"
}

fail() {
    printf "\r$DATETIME [ \033[0;31mERROR\033[0m ]%s\n" "$1"
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

get_cipher() {
    local IP=$1
    local PORT=$2

    for key in ${!IPListDict[@]}; do
        if [[ X"$IP:$PORT" == X"$key" ]]; then
            PASSWORD="${IPListDict[$key]}"
        fi
    done
}

is_exist() {
    local IP=$1

    if `grep -q "$IP" ${ssh_known_hosts}`; then
        return 0
    fi

    return 1
}

del_exist_host() {
    local IP=$1

    sed -i "/$IP/d" ${ssh_known_hosts}
}

generate_ssh_key() {
   if [ ! -f ${ssh_pri_key} ]; then
       ${ssh_keygen} -t ${ssh_key_type} -P "${ssh_pwd}" -f ${ssh_pri_key} &> /dev/null
       if [ $? -eq 0 ]; then
           log info "Generated ssh key successfully."
       else
           log err "Generated ssh key failed."
       fi
   else
       echo "y" | ${ssh_keygen} -t ${ssh_key_type} -P "${ssh_pwd}" -f ${ssh_pri_key} &> /dev/null
       if [ $? -eq 0 ]; then
           log info "Generated ssh key successfully."
       else
           log err "Generated ssh key failed."
       fi
   fi
}

copy_pub_key() {
   local IP=$1
   local PORT=$2

   if [ -f ${ssh_known_hosts} ]; then
       is_exist $IP
       if [ $? -eq 0 ]; then
           del_exist_host $IP
       fi
   fi
   
   get_cipher $IP $PORT
   
   expect -c <<- EOF &> /dev/null "
       spawn $ssh_copy_id -i "$ssh_pub_key" -p $PORT $USER_NAME@$IP
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
            expect eof    
        }
        catch wait retVal
        exit [lindex \$retVal 3]"
EOF
       if [ $? -eq 0 ]; then
           log info "Copy the ssh pub key to $IP successfully."
       else
           log err "Copy the ssh pub key to $IP failed."
       fi
}


# main
check_expect
generate_ssh_key
for element in ${!IPListDict[@]}; do
    IP=`echo "$element" | cut -d':' -f1`
    PORT=`echo "$element" | cut -d':' -f2`

    copy_pub_key $IP $PORT
done
