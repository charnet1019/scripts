#!/bin/bash

timestamp=$(date +%04Y%02m%02d%02H%02M)

# ########## 需要修改部分开始 #######################
# 指定备份后文件存储目录
BackupLocation="/data/backup"
LOG_FILE="/var/log/backup.log"
# 指定mysql命令所在路径，可以通过 which msyql查看
MYSQL_CMD="/usr/bin/mysql"
# 指定mysqldump命令所在路径
MYSQLDMUP_CMD="/usr/bin/mysqldump"

MYSQL_HOST="192.168.30.83"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASSWD="XpWQ9Hu5S0543WmE"

# ########## 需要修改部分结束 #######################


# 忽略不需要备份的数据库
IGNORE_DB="information_schema sys mysql performance_schema"


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


len() {
    local list=$1

    echo ${#list}
}

# ## 没有开启二进程日志时不需要--master-data参数
# --master-data=2
# --opt 包含: 
#       quick: 代表忽略缓冲输出
#       add-drop-table: 在每个CREATE TABLE命令之前增加DROP-TABLE IF EXISTS语句，防止数据表重名
#       add-locks: 在INSERT数据之前和之后锁定和解锁具体的数据表
#       extended-insert: 表示可以多选插入
#       lock-tables
# 使用GTID时备份需要增加  --set-gtid-purged=OFF

dumpdb() {
    local db_name=$1

    ${MYSQLDMUP_CMD} -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p"${MYSQL_PASSWD}" \
        --default-character-set=utf8 \
        --add-drop-database \
        --add-drop-table \
        --routines \
        --master-data=2 \
        --single-transaction \
        --events \
        --triggers \
        --databases ${db_name} > ${db_name}.sql
}

restore_db() {
    for file in $(ls); do
        echo $file
        ${MYSQL_CMD} -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p"${MYSQL_PASSWD}" < ${file}
        if [ $? -eq 0 ]; then
            log info "数据库${file}还原成功"
        else
            log err "数据库${file}还原失败"
        fi
    done
}

# 获取所有数据库
get_db() {
   local HOST=$1
   local PORT=$2
   local USER=$3
   local PASSWD=$4

   #DB=$(${MYSQL_CMD} --skip-column-names -h${HOST} -P${PORT} -u${USER} -p${PASSWD} -e "show databases;")
   echo $(${MYSQL_CMD} --skip-column-names -h${HOST} -P${PORT} -u${USER} -p${PASSWD} -e "show databases;")
}

compressFile() {
    local DB_NAME=$1

    tar -${compress_mode} "${DB_NAME}_${timestamp}.$CompressExtName" "${DB_NAME}".sql
    if [ $? -eq 0 ]; then
        log info "${DB_NAME}压缩成功"
    else
        log err "${DB_NAME}压缩失败"
    fi
}


enterWorkspace() {
    [ ! -d ${BackupLocation} ] && mkdir -p ${BackupLocation}
    cd ${BackupLocation}
}

deletePlainDumpout() {
    local db_list="$1"

    for db in ${db_list}; do
        rm -rf ${BackupLocation}/${db}.sql
        if [ $? -eq 0 ]; then
            log info "${db}.sql删除成功"
        else
            log err "${db}.sql删除失败"
        fi
    done
}

scpFileDump() {
    local db_list="$1"

    for db in ${db_list}; do
        scp "${BackupLocation}/${db}_${timestamp}.${CompressExtName}" "${BACKUP_REMOTE_SERVER}:${BACKUP_REMOTE_PATH}"
        if [ $? -eq 0 ]; then
            log info "成功将${BackupLocation}/${db}_${timestamp}.${CompressExtName}拷贝到${BACKUP_REMOTE_SERVER}:${BACKUP_REMOTE_PATH}"
        else
            log info "拷贝${BackupLocation}/${db}_${timestamp}.${CompressExtName}到远程服务器${BACKUP_REMOTE_SERVER}:${BACKUP_REMOTE_PATH}失败"
        fi
    done
}

clean_old_data() {
    local db_list="$1"

    for db in ${db_list}; do
        find ${BackupLocation} -name "${db}_*.${CompressExtName}" -type f -mtime +${RESERVE_DAYS} -exec rm {} \; > /dev/null 2>&1
    done
}

delete_old_data() {
    rm -f ${BackupLocation}/*
}


migration_to_qcloud_cos() {
    ${COS_MIGRATION_TOOL}
}

usage2() {
    echo "./$(basename "$0") [backup | restore]"
    echo "backup: 传backup表示备份数据"
    echo "restore: 传restore表示还原数据"
    echo "备份数据示例:"
    echo "./$(basename "$0") backup"
    echo ""
    echo "还原数据示例:"
    echo "./$(basename "$0") restore"
    exit 0
}

main() {

    if [ -z "${MODE}"  ]; then
        usage2
    fi

    enterWorkspace
   
    if [[ "${MODE}" == "backup" ]]; then
        ORIGIN_DB=$(get_db ${MYSQL_HOST} ${MYSQL_PORT} ${MYSQL_USER} ${MYSQL_PASSWD})
    
NEED_BK_DB=$(awk '{if(NR==1){for(i=1;i<=NF;i++){arr[$i]=1}} else {for(i=1;i<=NF;i++) {if(!arr[$i]) {print $i}}}}' << EOF
${IGNORE_DB}
${ORIGIN_DB}
EOF
)

        log info "***************************** 开始sql备份 ***********************************"
        for db in ${NEED_BK_DB}; do
            dumpdb ${db} 
            if [ $? -eq 0 ]; then
                log info "${db}备份成功"
            else
                log err "${db}备份失败"
            fi
        done
        log info "***************************** 完成sql备份 ***********************************"
    elif [[ "${MODE}" == "restore" ]]; then
        restore_db
    else
        echo "未知参数"
        usage2
    fi
}


# entrypoint
MODE=$1
main



