#!/usr/bin/env bash

# 备份es数据到COS

#elasticdump --input=http://10.10.3.13:19200/error_log --output=$ | gzip > /opt/cron/error_log.gz

ESDUMP="/usr/local/node-v16.13.0-linux-x64/bin/elasticdump"
GZIP="/usr/bin/gzip"
COS_MIGRATION_TOOL="/opt/cron/cos_migrate_tool_v5-1.4.5/start_migrate.sh"

ES_HOST=10.10.3.13
ES_PORT=19200
BACKUP_DIR="/data/backup"

timestamp=$(date +%04Y%02m%02d%02H%02M)
compress_mode="zcf"
CompressExtName="tar.gz"

FILENAME="zqy-prod-es"


INDICES="divide_record bury_point_log student_card sys_regions_new attendance_detail"

PATH=$PATH:/usr/local/node-v16.13.0-linux-x64/bin
export PATH

LOG_FILE="/var/log/backup.log"


success() {
    echo "$(date "+%F %T") [ INFO ]" "$1" | tee -a ${LOG_FILE}
    #echo "$(date "+%F %T") [ INFO ]" "$1" >> ${LOG_FILE}
}

warn() {
    echo "$(date "+%F %T") [ WARNING ]" "$1" | tee -a ${LOG_FILE}
    #echo "$(date "+%F %T") [ WARNING ]" "$1" >> ${LOG_FILE}
}

fail() {
    echo "$(date "+%F %T") [ ERROR ]" "$1" | tee -a ${LOG_FILE}
    #echo "$(date "+%F %T") [ ERROR ]" "$1" >> ${LOG_FILE}
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


enterWorkspace() {
    local base_path=$1

    [ ! -d ${base_path} ] && mkdir -p ${base_path}
    cd ${base_path}
}

compressFile() {
    local file_name=$1
    local mode=$2
    local time_stamp=$3
    local suffix=$4

    tar -${mode} "${file_name}_${time_stamp}.$suffix" *
    if [ $? -eq 0 ]; then
        log info "${file_name}压缩成功"
    else
        log err "${file_name}压缩失败"
        exit 1
    fi
}

clean_gz_file() {
    local base_path=$1

    log info "删除.gz压缩包"
    file_names=$(ls ${base_path})
    for file in ${file_names}; do
        suffix=${file#*.}
        if [[ "${suffix}" == "gz" ]]; then
            rm -f ${base_path}/${file}
        fi
    done
}

delete_old_data() {
    local base_path=$1

    log info "清空备份目录"
    rm -f ${base_path}/*
}

migration_to_qcloud_cos() {
    ${COS_MIGRATION_TOOL}
}

backup() {
    local HOST=$1
    local PORT=$2
    local INDXS=$3
    local BACK_PATH=$4

    for IDX in ${INDXS}; do
        {
            log info "开始备份索引${IDX}"
            log info "${ESDUMP} --concurrency=4 --limit=2000 --input=http://${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz"
            ${ESDUMP} --concurrency=4 --limit=2000 --input=http://${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz
            #${ESDUMP} --limit=2000 --input=http://${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz
            if [ $? -eq 0 ]; then
                log info "索引${IDX}备份成功"
            else
                log err "索引${IDX}备份失败"
                exit 1
            fi
        } &
    done

    wait
}

main() {
    for index in ${INDICES}; do
        backup ${ES_HOST} ${ES_PORT} ${index} ${BACKUP_DIR}
    done
    enterWorkspace ${BACKUP_DIR}
    compressFile ${FILENAME} ${compress_mode} ${timestamp} ${CompressExtName}
    clean_gz_file ${BACKUP_DIR}
    migration_to_qcloud_cos
    delete_old_data ${BACKUP_DIR}
}


# ############################ entrypoint ####################################3
main


