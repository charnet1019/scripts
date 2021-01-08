#!/bin/bash
# 功能: 通过percona xtrabackup备份mysql指定数据库

# 备注:
#    安装mysql时建议开启innodb_file_per_table设置，使不同的表位于独立的表空间中，方便后续备份时指定库或表.
# percona xtrabackup安装:
#yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm
#yum install -y percona-xtrabackup-24


timestamp=$(date +%04Y%02m%02d%02H%02M)
PREFIX_NAME="mysql_50_9"
COMPRESS_CMD_OPTION="-zcf"
COMPRESS_SUBFIX="tar.gz"
FINAL_NAME="${PREFIX_NAME}_${timestamp}.${COMPRESS_SUBFIX}"

REMOTE_SRV_HOST="10.100.50.44"
REMOTE_SRV_STORAGE_DIR="/data/backup/mysql/10_100_50_9"


MYSQL_HOST="10.100.50.9"
MYSQL_PORT="3307"
MYSQL_USER="root"
MYSQL_PASSWD="9MJIEG1eBf6s"

# 被备份数据库配置文件
DB_CONFIG="/opt/mysql/master/my.cnf"
# 被备份数据库数据存储路径
DB_DATA_DIR="/opt/mysql/master/data"
# 备份后数据存储路径
DB_BACKUP_DIR="/data/backup"

MYSQL_CMD="/opt/cron/mysql"
INNO_CMD="/usr/bin/innobackupex"

LOG_FILE="/var/log/mysql_backup.log"

#BK_DB="mysql my_facility_manage"

# 忽略不需要备份的数据库
IGNORE_DB="
information_schema
sys
"

#IGNORE_DB="
#information_schema
#performance_schema
#sys
#"


# 获取所有数据库
get_db() {
   local HOST=$1
   local PORT=$2
   local USER=$3
   local PASSWD=$4

   DB=$(${MYSQL_CMD} --skip-column-names -h${HOST} -P${PORT} -u${USER} -p${PASSWD} -e "show databases;")
}


# 备份数据库
bk_db_by_percona() {
    local CONFIG=$1
    local HOST=$2
    local PORT=$3
    local USER=$4
    local PASSWD=$5
    local DB_DATA_DIR=$6
    local DB_NAME="$7"
    local BK_DIR=$8

    echo "$(date "+%F %T") 开始备份数据库: ${DB_NAME}" >> ${LOG_FILE}
    echo "$(date "+%F %T") 备份执行命令: ${INNO_CMD} --defaults-file=${CONFIG} --host=${HOST} --port=${PORT} --user=${USER} --password=${PASSWD} --datadir=${DB_DATA_DIR} --databases=${DB_NAME} ${BK_DIR}" >> ${LOG_FILE}
    ${INNO_CMD} --defaults-file=${CONFIG} --host=${HOST} --port=${PORT} --user=${USER} --password=${PASSWD} --datadir=${DB_DATA_DIR} --databases="${DB_NAME}" "${BK_DIR}" >> ${LOG_FILE} 2>&1
    echo "$(date "+%F %T") 数据库备份完成: ${DB_NAME}" >> ${LOG_FILE}
    echo -e "\n" >> ${LOG_FILE}
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> ${LOG_FILE}
}


enter_workspace() {
	local BK_DIR="$1"
	
    if [ ! -d ${BackupLocation} ]; then
        echo "----- 数据备份目录不存在请确认" >> ${LOG_FILE}
        exit 4
    fi

    cd ${BK_DIR}
}

compress_file() {
	local CMD_OPTION=$1
    local FILE_NAME=$2
	local BK_DIR=$3

	ARCHIVE=$(ls -l ${BK_DIR} | grep "^d" | awk '{print $NF}')

    tar ${CMD_OPTION} "${FILE_NAME}" "${ARCHIVE}"
	if [ $? -ne 0 ]; then
        echo "----- 压缩备份数据失败" >> ${LOG_FILE}
	    exit 1
	fi
}

delete_plain_dumpout() {
	local BK_DIR="$1"

    cd "${BK_DIR}"
	rm -rf $(ls ${BK_DIR} | egrep -v '(*.tar.gz)')
	if [ $? -ne 0 ]; then
        echo "------- 删除未压缩备份数据失败" >> ${LOG_FILE}
	    exit 2
    fi
}


scp_to_remote_srv() {
	local FILE="$1"
    local REMOTE_HOST="$2"
    local REMOTE_DIR="$3"

    scp "${FILE}" "${REMOTE_HOST}:${REMOTE_DIR}"
	if [ $? -ne 0 ]; then
        echo "------ 复制备份数据到远程服务器失败" >> ${LOG_FILE}
        exit 3
    fi
}


main() {
    get_db ${MYSQL_HOST} ${MYSQL_PORT} ${MYSQL_USER} ${MYSQL_PASSWD}
    # 保存需要备份的数据库名, 以空格分隔
    DB_LIST=""
    for d in ${DB}; do
        if [[ "${IGNORE_DB[@]}" =~ "${d}" ]]; then
    	    continue
        else
            DB_LIST="${d} ${DB_LIST}"
        fi
    done

    r=$(ls ${DB_BACKUP_DIR})
    if [[ X"$r" != X"" ]]; then
        echo "$(date "+%F %T") 备份前清理老数据开始" >> ${LOG_FILE}
        echo "$(date "+%F %T") 清理老数据执行命令: rm -rf ${DB_BACKUP_DIR}/*" >> ${LOG_FILE}
        rm -rf ${DB_BACKUP_DIR}/*
        echo "$(date "+%F %T") 备份前清理老数据结束" >> ${LOG_FILE}
    fi
    
    # 备份数据
    bk_db_by_percona ${DB_CONFIG} ${MYSQL_HOST} ${MYSQL_PORT} ${MYSQL_USER} ${MYSQL_PASSWD} ${DB_DATA_DIR} "${DB_LIST}" ${DB_BACKUP_DIR}

    # 进入备份数据目录
    enter_workspace ${DB_BACKUP_DIR}
    # 压缩备份数据
	compress_file ${COMPRESS_CMD_OPTION} ${FINAL_NAME} ${DB_BACKUP_DIR}
    # 删除未压缩备份数据
	delete_plain_dumpout ${DB_BACKUP_DIR}
    # 同步到远程服务器
	scp_to_remote_srv ${FINAL_NAME} ${REMOTE_SRV_HOST} ${REMOTE_SRV_STORAGE_DIR}
}



# ############# main 
main






