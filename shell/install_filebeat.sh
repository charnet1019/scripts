#!/bin/bash

INSTALL_DIR="/opt"

FILEBAET_PKG_FULL_NAME="filebeat-7.9.1-linux-x86_64.tar.gz"
FILEBEAT_PKG_BASE_NAME="${FILEBAET_PKG_FULL_NAME%.tar*}"

DOWNLOAD_PATH="/opt/src"
DOWNLOAD_SERVER="http://10.100.10.64:9999/soft"
DOWNLOAD_URL="${DOWNLOAD_SERVER}/${FILEBAET_PKG_FULL_NAME}"


KAFKA_NODE01="10.100.50.90:9092"
KAFKA_NODE02="10.100.50.91:9092"
KAFKA_NODE03="10.100.50.92:9092"

FILEBEAT_LOG_PATH="/opt/mysql/master/log/slow.log"
FILEBEAT_LOG_TYPE="prod_misc_mysql_slowlog"
FILEBEAT_LOG_TAG="prodmysql"
FILEBEAT_HOST_IP=$(ifconfig $(route | awk 'NR==3 {print}' | awk '{print $NF}') | grep -w inet | awk '{print $2}')

DATETIME=`date "+%F %T"`
LOG_FILE="/var/log/my.log"

success() {
    #echo "$DATETIME [ INFO ]" "$1" | tee -a ${LOG_FILE}
    echo "$(date "+%F %T") [ INFO ]" "$1" | tee -a ${LOG_FILE}
    #echo "$DATETIME [ INFO ]" "$1" >> ${LOG_FILE}
}

warn() {
    #echo "$DATETIME [ WARNING ]" "$1" | tee -a ${LOG_FILE}
    echo "$(date "+%F %T") [ WARNING ]" "$1" | tee -a ${LOG_FILE}
    #echo "$DATETIME [ WARNING ]" "$1" >> ${LOG_FILE}
}

fail() {
    #echo "$DATETIME [ ERROR ]" "$1" | tee -a ${LOG_FILE}
    echo "$(date "+%F %T") [ ERROR ]" "$1" | tee -a ${LOG_FILE}
    #echo "$DATETIME [ ERROR ]" "$1" >> ${LOG_FILE}
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



add_grp() {
    local grp="$1"

    groupadd ${grp}
    if [ $? -eq 0 ]; then
        log info "已添成功加组${grp}"
    else
        log err "组${grp}添加失败"
        exit 1
    fi
}

add_user() {
    local grp="$1"
    local usr="$2"

    useradd -g ${grp} ${usr}
    if [ $? -eq 0 ]; then
        log info "已成功添加用户${usr}"
    else
        log err "用户${usr}添加失败"
        exit 1
    fi
}

download() {
    local download_url="$1"      # 文件下载路径
    local download_path="$2"     # 文件下载存储路径
    local pkg_full_name="$3"     # 文件压缩包名

    [ ! -d "${download_path}" ] && mkdir -p ${download_path}
    #cd ${download_path}
    if [ ! -f ${download_path}/${pkg_full_name} ]; then
        curl -C - -L "${download_url}" -o ${download_path}/${pkg_full_name}
        if [ $? -eq 0 ]; then
            log info "${pkg_full_name}下载成功"
        else
            log err "${pkg_full_name}下载失败"
            exit 1
        fi
    fi
}

install() {
    local download_path="$1"      # 文件下载路径
    local pkg_base_name="$2"      # 文件名
    local pkg_full_name="$3"      # 文件压缩包名
    local inst_dir="$4"           # 安装路径

    if [ ! -d ${download_path}/${pkg_base_name} ]; then
        tar xf ${download_path}/${pkg_full_name} -C ${inst_dir}
        if [ $? -eq 0 ]; then
            log info "成功解压${pkg_full_name}到${inst_dir}"
        else
            log err "${pkg_full_name}解压失败"
            exit 1
        fi
    else
		log warn "${pkg_base_name}已安装."
        exit 1
    fi
}


gen_filebeat_config() {
   local inst_dir="$1"
   local pkg_base_name="$2"
   local log_path="$3"
   local log_type="$4"
   local log_tag="$5"
   local host_ip="$6"
   local kf1="$7"
   local kf2="$8"
   local kf3="$9"

   mv ${inst_dir}/${pkg_base_name}/filebeat.yml ${inst_dir}/${pkg_base_name}/filebeat.yml.bak
   if [ $? -eq 0 ]; then
       log info "filebeat.yml备份成功."
   else
       log err "filebeat.yaml备份失败"
       exit 1
   fi
   cat > ${inst_dir}/${pkg_base_name}/filebeat.yml <<- EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - ${log_path}
  fields:
      log_type: ${log_type}
  tags: ["${log_tag}"]
  multiline.pattern: '^# Time'
  multiline.negate: true
  multiline.match: after
filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: false
setup.template.settings:
  index.number_of_shards: 1
name: ${host_ip}
setup.kibana:
output.kafka:
  enabled: true
  topic: '%{[fields.log_type]}'
  hosts: ["${kf1}", "${kf2}", "${kf3}"]
  compression: gzip
  max_message_bytes: 10000000
  codec.json:
    pretty: false
processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
  - drop_fields:
      fields: ["agent_ephemeral_id", "agent.hostname", "agent.id", "agent.version", "agent.type", "ecs.version", "host.architecture", "host.containerized", "host.hostname", "host.id", "host.mac", "host.os.codename", "host.os.family", "host.os.kernel", "host.os.name", "host.os.platform", "host.os.version"]
EOF
    if [ $? -eq 0 ]; then
        log info "${pkg_base_name%%-*}配置文件生成成功."
    else
        log err "${pkg_base_name%%-*}配置文件生成失败."
        exit 1
    fi
}



# ######################## enterypoint
download "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}" "${FILEBAET_PKG_FULL_NAME}"
install "${DOWNLOAD_PATH}" "${FILEBEAT_PKG_BASE_NAME}" "${FILEBAET_PKG_FULL_NAME}" "${INSTALL_DIR}"
gen_filebeat_config "${INSTALL_DIR}" "${FILEBEAT_PKG_BASE_NAME}" "${FILEBEAT_LOG_PATH}" "${FILEBEAT_LOG_TYPE}" "${FILEBEAT_LOG_TAG}" "${FILEBEAT_HOST_IP}" "${KAFKA_NODE01}" "${KAFKA_NODE02}" "${KAFKA_NODE03}"


log info "------------ 安装完成 ---------------"



