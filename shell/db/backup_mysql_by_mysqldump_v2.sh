#!/bin/bash

timestamp=$(date +%04Y%02m%02d%02H%02M)
# 备份存储目录
BackupLocation="/data/backup"
LOG_FILE="/var/log/backup.log"
MYSQL_CMD="/usr/bin/mysql"
MYSQLDMUP_CMD="/usr/bin/mysqldump"

#MYSQL_HOST="172.18.30.4"
#MYSQL_PORT="33061"
#MYSQL_USER="root"
#MYSQL_PASSWD="yA/lfg+xxxxxx6jhw"

declare -A IPListDict

# 默认全部使用root用户
MYSQL_USER="root"
# 备份数据库主机IP地址和密码，每行一个主机
IPListDict=(
[192.168.0.211:3306]='Wimj@$1209'
[192.168.0.212:3306]='Wimj@$1209'
)

# 备份数据上传到腾讯云COS
#COS_MIGRATION_TOOL="/opt/cron/cos_migrate_tool_v5-1.4.5/start_migrate.sh"


compress_mode="zcf"
CompressExtName="tar.gz"

RESERVE_DAYS=5

# 忽略不需要备份的数据库
#IGNORE_DB="information_schema sys mysql performance_schema"
IGNORE_DB="information_schema sys performance_schema"


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
    local mysql_host=$1
    local mysql_port=$2
    local mysql_user=$3
    local mysql_password=$4
    local db_name=$5

    ${MYSQLDMUP_CMD} -h${mysql_host} -P${mysql_port} -u${mysql_user} -p"${mysql_password}" \
        --default-character-set=utf8 \
        --add-drop-database \
        --add-drop-table \
        --routines \
        --master-data=2 \
        --single-transaction \
        --events \
        --triggers \
        --databases ${db_name} > ${db_name}_${mysql_host}.sql
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

get_cipher() {
    local IP=$1
    local PORT=$2

    for key in ${!IPListDict[@]}; do
        if [[ X"$IP:$PORT" == X"$key" ]]; then
            PASSWORD="${IPListDict[$key]}"
            echo "${PASSWORD}"
        fi
    done
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


#migration_to_qcloud_cos() {
#    ${COS_MIGRATION_TOOL}
#}


main() {
    enterWorkspace

    for item in ${!IPListDict[@]}; do
        IP=`echo "$item" | cut -d':' -f1`
        PORT=`echo "$item" | cut -d':' -f2`
        PASSWD=$(get_cipher ${IP} ${PORT})

        ORIGIN_DB=$(get_db ${IP} ${PORT} ${MYSQL_USER} ${PASSWD})
        NEED_BK_DB=$(awk '{if(NR==1){for(i=1;i<=NF;i++){arr[$i]=1}} else {for(i=1;i<=NF;i++) {if(!arr[$i]) {print $i}}}}' << EOF
${IGNORE_DB}
${ORIGIN_DB}
EOF
)
        log info "***************************** 开始sql备份 ***********************************"
        for db in ${NEED_BK_DB}; do
            dumpdb ${IP} ${PORT} ${MYSQL_USER} ${PASSWD} ${db} 
            if [ $? -eq 0 ]; then
                log info "${db}备份成功"
            else
                log err "${db}备份失败"
            fi
            #compressFile "${db}"
        done
        log info "***************************** 完成sql备份 ***********************************"
    done

    


    #deletePlainDumpout "${NEED_BK_DB}"
    #migration_to_qcloud_cos
    #sleep 3
    #delete_old_data

    #scpFileDump "${DB}"
    #clean_old_data "${DB}"
}


# entrypoint
main






