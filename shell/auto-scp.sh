#!/bin/bash

##########################################################
#
# Copyright (2017-10-21, )
#
# Author: charnet1019@163.com
# Last modified: 2017-10-22 00:06
# Description: 
#
##########################################################

# definition IP dictionary array
declare -A IPListDict

# 所有主机默认使用root帐号
USERNAME=root
# 本地要拷贝的文件
LOCAL="/home/main.py"
# 拷贝到远程主机的位置
REMOTE="/opt/"

# 格式: 主机IP:端口=密码，每行一个主机，密码为空则为免密连接
IPListDict=(
[192.168.2.7:22]=""
)

ssh_key_base_dir=~/.ssh
ssh_known_hosts=$ssh_key_base_dir/known_hosts
SCP=`which scp`

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

#is_exist_hosts() {
#    local FILE=$1
#
#    [ -f ${FILE} ] && return 0 || return 1
#}

get_cipher() {
    local IP=$1
    local PORT=$2

    for key in ${!IPListDict[@]}; do
        if [[ X"$IP:$PORT" == X"$key" ]]; then
            PASSWORD="${IPListDict[$key]}"
        fi
    done
}

exec_cp() {
    for item in ${!IPListDict[@]}; do
        IP=`echo "$item" | cut -d':' -f1`
        PORT=`echo "$item" | cut -d':' -f2`
    
        get_cipher $IP $PORT
        if [ X"${PASSWORD}" != X"" ]; then
            expect -c  <<- EOF &> /dev/null "
                spawn $SCP -P $PORT -r $LOCAL $USERNAME@$IP:$REMOTE
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
                log info "The file $LOCAL copy to the remote host $IP:${REMOTE} successed."
            else
                log err "The file $LOCAL copy to the remote host $IP:${REMOTE} failed."
            fi
        else
            $SCP -P $PORT -r $LOCAL $USERNAME@$IP:$REMOTE
            if [ $? -eq 0 ]; then
                log info "The file $LOCAL copy to the remote host $IP:${REMOTE} successed."
            else
                log err "The file $LOCAL copy to the remote host $IP:${REMOTE} failed."
            fi
        fi    
    done
}

# ##### main entrypoint
check_expect
exec_cp
