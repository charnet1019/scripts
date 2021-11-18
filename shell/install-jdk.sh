#!/bin/bash

PKG_NAME="jdk-8u281-linux-x64.tar.gz"
URL="http://10.18.1.5:58848/software/jdk/${PKG_NAME}"
DOWNLOAD_DIR="/home/src"
INST_DIR="/usr/local"



command_exists() {
	command -v "$@" > /dev/null 2>&1
}

download() {
    local download_dir=$1
    local download_url=$2

    [ ! -d ${download_dir} ] && mkdir -p ${download_dir}
    wget ${download_url} -P ${download_dir}
}

extract() {
    local pkg_dir=$1
    local pkg_name=$2
    local install_dir=$3

    tar zxvf ${pkg_dir}/${pkg_name} -C ${install_dir}
}

set_profile() {
    cat >> /etc/profile.d/java.sh << "EOF"
JAVA_HOME=/usr/local/jdk1.8.0_281
PATH=$JAVA_HOME/bin:$PATH
CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar

export JAVA_HOME PATH CLASSPATH
EOF

    source  /etc/profile.d/java.sh
}

main() {
    if command_exists java; then
        echo "java already exist."
        exit 0
    else
        download ${DOWNLOAD_DIR} ${URL}
        extract ${DOWNLOAD_DIR} ${PKG_NAME} ${INST_DIR}
        set_profile

        if command_exists java; then
            echo "jdk install successful."
            exit 0
        else
            echo "jdk install failure."
            exit 1
        fi
    fi
}



# ######################## entrypoint #############################
main



