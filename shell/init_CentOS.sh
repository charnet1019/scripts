#!/bin/bash

UBUNTU_CHRONY_CONFIG="/etc/chrony/chrony.conf"
CENTOS_CHRONY_CONFIG="/etc/chrony.conf"


echo=echo
for cmd in echo /bin/echo; do
  $cmd >/dev/null 2>&1 || continue
  if ! $cmd -e "" | grep -qE '^-e'; then
    echo=$cmd
    break
  fi
done

CSI=$($echo -e "\033[")
CEND="${CSI}0m"
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"
CSUCCESS="$CDGREEN"
CFAILURE="$CRED"
CQUESTION="$CMAGENTA"
CWARNING="$CYELLOW"
CMSG="$CCYAN"

if [[ "$(whoami)" != "root" ]]; then
    echo "please run this script as root !" >&2
    exit 1
fi

# update os
yum -y update

# Close SELINUX
setenforce 0
sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config


# /etc/security/limits.conf
[ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
sed -i.bak '/^# End of file/,$d' /etc/security/limits.conf
cat >> /etc/security/limits.conf <<EOF
# End of file
* soft nproc 1000000
* hard nproc 1000000
* soft nofile 1000000
* hard nofile 1000000
EOF

# /etc/hosts
#[ "$(hostname -i | awk '{print $1}')" != "127.0.0.1" ] && sed -i "s@127.0.0.1.*localhost@&\n127.0.0.1 $(hostname)@g" /etc/hosts

# Set timezone
timezone=Asia/Shanghai
rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/${timezone} /etc/localtime

# Set DNS
#cat > /etc/resolv.conf << EOF
#nameserver 114.114.114.114
#nameserver 8.8.8.8
#EOF

# ip_conntrack table full dropping packets
[ ! -e "/etc/sysconfig/modules/iptables.modules" ] && { echo -e "modprobe nf_conntrack\nmodprobe nf_conntrack_ipv4" > /etc/sysconfig/modules/iptables.modules; chmod +x /etc/sysconfig/modules/iptables.modules; }
modprobe nf_conntrack
modprobe nf_conntrack_ipv4
echo options nf_conntrack hashsize=131072 > /etc/modprobe.d/nf_conntrack.conf

# /etc/sysctl.conf
[ ! -e "/etc/sysctl.conf_bk" ] && /bin/mv /etc/sysctl.conf{,_bk}
cat > /etc/sysctl.conf << EOF
fs.file-max=1000000
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.ipv4.tcp_max_syn_backlog = 16384
net.core.netdev_max_backlog = 32768
net.core.somaxconn = 32768
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_syncookies = 1
#net.ipv4.tcp_tw_len = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.ip_local_port_range = 1024 65000
net.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sysctl -p

yum -y install redhat-lsb-core

# Get OS Version
if [ -e /etc/redhat-release ]; then
  OS=CentOS
  CentOS_ver=$(lsb_release -sr | awk -F. '{print $1}')
  [[ "$(lsb_release -is)" =~ ^Aliyun$|^AlibabaCloudEnterpriseServer$ ]] && { CentOS_ver=7; Aliyun_ver=$(lsb_release -rs); }
  [[ "$(lsb_release -is)" =~ ^EulerOS$ ]] && { CentOS_ver=7; EulerOS_ver=$(lsb_release -rs); }
  [ "$(lsb_release -is)" == 'Fedora' ] && [ ${CentOS_ver} -ge 19 >/dev/null 2>&1 ] && { CentOS_ver=7; Fedora_ver=$(lsb_release -rs); }
elif [ -n "$(grep 'Amazon Linux' /etc/issue)" -o -n "$(grep 'Amazon Linux' /etc/os-release)" ]; then
  OS=CentOS
  CentOS_ver=7
elif [ -n "$(grep 'bian' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == "Debian" ]; then
  OS=Debian
  Debian_ver=$(lsb_release -sr | awk -F. '{print $1}')
elif [ -n "$(grep 'Deepin' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == "Deepin" ]; then
  OS=Debian
  Debian_ver=8
elif [ -n "$(grep -w 'Kali' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == "Kali" ]; then
  OS=Debian
  if [ -n "$(grep 'VERSION="2016.*"' /etc/os-release)" ]; then
    Debian_ver=8
  elif [ -n "$(grep 'VERSION="2017.*"' /etc/os-release)" ]; then
    Debian_ver=9
  elif [ -n "$(grep 'VERSION="2018.*"' /etc/os-release)" ]; then
    Debian_ver=9
  fi
elif [ -n "$(grep 'Ubuntu' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == "Ubuntu" -o -n "$(grep 'Linux Mint' /etc/issue)" ]; then
  OS=Ubuntu
  Ubuntu_ver=$(lsb_release -sr | awk -F. '{print $1}')
  [ -n "$(grep 'Linux Mint 18' /etc/issue)" ] && Ubuntu_ver=16
elif [ -n "$(grep 'elementary' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'elementary' ]; then
  OS=Ubuntu
  Ubuntu_ver=16
fi

if [ "${CentOS_ver}" == '6' ]; then
  sed -i 's@^ACTIVE_CONSOLES.*@ACTIVE_CONSOLES=/dev/tty[1-2]@' /etc/sysconfig/init
  sed -i 's@^start@#start@' /etc/init/control-alt-delete.conf
  sed -i 's@LANG=.*$@LANG="en_US.UTF-8"@g' /etc/sysconfig/i18n
elif [ ${CentOS_ver} -ge 7 >/dev/null 2>&1 ]; then 
  sed -i 's@LANG=.*$@LANG="en_US.UTF-8"@g' /etc/locale.conf
fi

[ "${CentOS_ver}" == '8' ] && dnf --enablerepo=PowerTools install -y rpcgen


command_exists() {
	command -v "$@" > /dev/null 2>&1
}

yum_install_pkgs() {
    local PKG_NAME=$1
    local BIN_NAME=$2

    if ! command_exists ${BIN_NAME} &> /dev/null; then
        yum -y install ${PKG_NAME}
        if ! command_exists ${BIN_NAME} &> /dev/null; then
            echo "${PKG_NAME} service install failed, please install it manually."
            exit 1
        fi
    else
        echo "${PKG_NAME} service already exist."
    fi
}

apt_install_pkgs() {
    local PKG_NAME=$1
    local BIN_NAME=$2

    if ! command_exists ${BIN_NAME} &> /dev/null; then
        apt-get -y install ${PKG_NAME} &> /dev/null
        if ! command_exists ${BIN_NAME} &> /dev/null; then
            echo "${PKG_NAME} service install failed, please install it manually."
            exit 1
        fi
    else
        echo "${PKG_NAME} service already exist."
    fi
}

update_ubuntu_chrony_config() {
    sed -i 's/^\(pool .*\)/#\1/g' ${UBUNTU_CHRONY_CONFIG}
    echo "pool ntp1.aliyun.com online iburst" >> ${UBUNTU_CHRONY_CONFIG}
    echo "pool ntp2.aliyun.com online iburst" >> ${UBUNTU_CHRONY_CONFIG}
    echo "pool ntp3.aliyun.com online iburst" >> ${UBUNTU_CHRONY_CONFIG}
}

update_centos_chrony_config() {
    sed -i 's/^\(server .*\)/#\1/g' ${CENTOS_CHRONY_CONFIG}
    echo "server ntp1.aliyun.com iburst" >> ${CENTOS_CHRONY_CONFIG}
    echo "server ntp2.aliyun.com iburst" >> ${CENTOS_CHRONY_CONFIG}
    echo "server ntp3.aliyun.com iburst" >> ${CENTOS_CHRONY_CONFIG}
}

start_service() {
    local SRV_NMAE=$1

    systemctl restart ${SRV_NMAE} &> /dev/null
    systemctl enable ${SRV_NMAE} &> /dev/null

    if systemctl status ${SRV_NMAE} &> /dev/null; then
        echo "${SRV_NMAE} started successfully."
    else
        echo "${SRV_NMAE} start failed."
    fi
}

# Update time
#if [ -e "$(which ntpdate)" ]; then
#  ntpdate -u pool.ntp.org
#  [ ! -e "/var/spool/cron/root" -o -z "$(grep 'ntpdate' /var/spool/cron/root)" ] && { echo "*/20 * * * * $(which ntpdate) -u pool.ntp.org > /dev/null 2>&1" >> /var/spool/cron/root;chmod 600 /var/spool/cron/root; }
#fi
if [ ${OS} == "CentOS" ]; then
    yum_install_pkgs chrony chronyd
    update_centos_chrony_config
    start_service chronyd
elif [ ${OS} == "Debian" -o ${OS} == "Ubuntu" ]; then
    apt_install_pkgs chrony chronyd
    update_ubuntu16_chrony_config
    start_service chrony
fi


# log
mk_record() {
    [ ! -d /var/log/records ] && mkdir -p /var/log/records
    chmod 666 /var/log/records
    #chmod +t /var/log/records


cat >> /etc/profile.d/record.sh << "EOF"
if [ ! -d /var/log/records/${LOGNAME} ]; then
    mkdir -p /var/log/records/${LOGNAME}
    chmod 300 /var/log/records/${LOGNAME}
fi

export HISTORY_FILE="/var/log/records/${LOGNAME}/bash_history"
export PROMPT_COMMAND='{ date "+%Y-%m-%d %T ##### $(who am i | awk "{print \$1\" \"\$2\" \"\$5}") #### $(history 1 | { read x cmd; echo "$cmd"; })"; } >>$HISTORY_FILE'
EOF

source /etc/profile.d/record.sh
}

mk_record


services_optimizer() {
    systemctl stop postfix.service
    systemctl disable postfix.service
}

services_optimizer

# iptables
#if [ "${iptables_flag}" == 'y' ]; then
#  if [ -e "/etc/sysconfig/iptables" ] && [ -n "$(grep '^:INPUT DROP' /etc/sysconfig/iptables)" -a -n "$(grep 'NEW -m tcp --dport 22 -j ACCEPT' /etc/sysconfig/iptables)" -a -n "$(grep 'NEW -m tcp --dport 80 -j ACCEPT' /etc/sysconfig/iptables)" ]; then
#    IPTABLES_STATUS=yes
#  else
#    IPTABLES_STATUS=no
#  fi
#
#  if [ "$IPTABLES_STATUS" == "no" ]; then
#    [ -e "/etc/sysconfig/iptables" ] && /bin/mv /etc/sysconfig/iptables{,_bk}
#    cat > /etc/sysconfig/iptables << EOF
## Firewall configuration written by system-config-securitylevel
## Manual customization of this file is not recommended.
#*filter
#:INPUT DROP [0:0]
#:FORWARD ACCEPT [0:0]
#:OUTPUT ACCEPT [0:0]
#:syn-flood - [0:0]
#-A INPUT -i lo -j ACCEPT
#-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
#-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
#-A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
#-A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
#-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
#COMMIT
#EOF
#  fi
#
#  FW_PORT_FLAG=$(grep -ow "dport ${ssh_port}" /etc/sysconfig/iptables)
#  [ -z "${FW_PORT_FLAG}" -a "${ssh_port}" != "22" ] && sed -i "s@dport 22 -j ACCEPT@&\n-A INPUT -p tcp -m state --state NEW -m tcp --dport ${ssh_port} -j ACCEPT@" /etc/sysconfig/iptables
#  /bin/cp /etc/sysconfig/{iptables,ip6tables}
#  sed -i 's@icmp@icmpv6@g' /etc/sysconfig/ip6tables
#  iptables-restore < /etc/sysconfig/iptables
#  ip6tables-restore < /etc/sysconfig/ip6tables
#  service iptables save
#  service ip6tables save
#  chkconfig --level 3 iptables on
#  chkconfig --level 3 ip6tables on
#fi
#service rsyslog restart
#service sshd restart
#
#. /etc/profile

while :; do 
    echo
    echo "${CMSG}Please restart the server and see if the services start up fine.${CEND}"
    read -e -p "Do you want to restart OS ? [y/n]: " reboot_flag
    if [[ ! "${reboot_flag}" =~ ^[y,n]$ ]]; then
        echo "${CWARNING}Input error! Please only input 'y' or 'n'${CEND}"
    else
        break
    fi
done

[ "${reboot_flag}" == 'y' ] && reboot




