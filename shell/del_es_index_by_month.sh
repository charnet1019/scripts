#/usr/bin/env bash

# Author: pengchanghong
# Date: 20190313
# 删除不以点开头的索引

# 定期删除系统业务日志
# 保留最近180天数据

ESIP=10.10.10.10
ESPORT=19200
# 没有用户名和密码则留空
ES_USERNAME="elastic"
ES_PASSWORD="yeIxxxxxxxxMDVV"
#保留最近N天的日志
MAXLIFE=180

ESDUMP="/usr/local/node-v16.17.1-linux-x64/bin/elasticdump"
GZIP="/usr/bin/gzip"
# es数据备份目录
BACKUP_DIR="/backup/sdp"

[ ! -d "${BACKUP_DIR}" ] && mkdir "${BACKUP_DIR}"

timestamp=$(date +%04Y%02m%02d%02H%02M)
compress_mode="zcf"
CompressExtName="tar.gz"

PATH=$PATH:/usr/local/node-v16.17.1-linux-x64/bin
export PATH

# 索引格式
# myindex-2022-10

LOGFILE="/var/log/my-job-es.log"

if [ ! -f $LOGFILE ]; then
    touch $LOGFILE
fi

success() {
    echo "$(date "+%F %T") [ INFO ]" "$1" | tee -a ${LOGFILE}
    #echo "$(date "+%F %T") [ INFO ]" "$1" >> ${LOGFILE}
}

warn() {
    echo "$(date "+%F %T") [ WARNING ]" "$1" | tee -a ${LOGFILE}
    #echo "$(date "+%F %T") [ WARNING ]" "$1" >> ${LOGFILE}
}

fail() {
    echo "$(date "+%F %T") [ ERROR ]" "$1" | tee -a ${LOGFILE}
    #echo "$(date "+%F %T") [ ERROR ]" "$1" >> ${LOGFILE}
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


# 备份索引
backup() {
    local HOST=$1
    local PORT=$2
    #local INDXS=$3
    local IDX=$3
    local BACK_PATH=$4
    local es_username="${5:-}"
    local es_password="${6:-}"

    if [ -n "${es_host}" -a -n "${es_port}" -a -z "${es_username}" -a -z "${es_password}" ]; then
        log info "开始备份索引${IDX}"
        log info "${ESDUMP} --concurrency=4 --limit=2000 --input=http://${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz"
        ${ESDUMP} --concurrency=4 --limit=2000 --input=http://${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz
        if [ $? -eq 0 ]; then
            log info "索引${IDX}备份成功"
        else
            log err "索引${IDX}备份失败"
            exit 1
        fi 
    elif [ -n "${es_host}" -a -n "${es_port}" -a -n "${es_username}" -a -n "${es_password}" ]; then
        log info "开始备份索引${IDX}"
        log info "${ESDUMP} --concurrency=4 --limit=2000 --input=http://elastic:xxxxx@${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz"
        ${ESDUMP} --concurrency=4 --limit=2000 --input=http://${es_username}:${es_password}@${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz
        if [ $? -eq 0 ]; then
            log info "索引${IDX}备份成功"
        else
            log err "索引${IDX}备份失败"
            exit 1
        fi 
    fi

    #for IDX in ${INDXS}; do
    #    {
    #        log info "开始备份索引${IDX}"
    #        log info "${ESDUMP} --concurrency=4 --limit=2000 --input=http://${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz"
    #        ${ESDUMP} --concurrency=4 --limit=2000 --input=http://${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz
    #        #${ESDUMP} --limit=2000 --input=http://${HOST}:${PORT}/${IDX} --output=$ | ${GZIP} > ${BACK_PATH}/${IDX}.gz
    #        if [ $? -eq 0 ]; then
    #            log info "索引${IDX}备份成功"
    #        else
    #            log err "索引${IDX}备份失败"
    #            exit 1
    #        fi
    #    } &
    #done

    wait
}


is_delete(){
    if [ $(($1-$2)) -gt 0 ]; then
        return 1
    fi

    return 0
}


# 判断索引是否��点开头
# 以点开头则返回false
# 不以点开头则返回true
is_start_with_dot() {
    local str="$1"

    if [[ ${str} =~ ^\..* ]]; then
        return `true`
    fi

    return `false`
}


# 索引格式符合 dev-qxy-2021.04.19 或 dev-qxy-20210419则返回真，否则，返回假
verify_index_format() {
    local idx=$1

    # 判断索引中是否包含"-"
    result=$(echo ${idx} | grep "-")
    if [[ "${result}" != "" ]]; then
        idx_date=$(echo ${idx} | awk -F- '{print $NF}' | sed 's/\./-/g')
        if date -d "${idx_date}" "+%s" &> /dev/null; then
             return $(true)
        fi
    fi

    return $(false)
}


verify_index_formats() {
    local idx=$1

    #echo $idx
    # 判断索引中是否包含"-"
    result=$(echo ${idx} | grep "-")
    if [[ "${result}" != "" ]]; then
        #idx_date=$(echo ${idx} | awk -F- '{print $NF}' | sed 's/\./-/g')
        middle_inx_date=${idx#*-}
        idx_date=$(echo ${middle_inx_date} | sed 's/\./-/g')
        echo "----${idx_date}"
        if date -d "${idx_date}" "+%s" &> /dev/null; then
             return $(true)
        fi
    fi

    return $(false)
}


is_force_merge() {
    if [ $(($2-$1)) -ge 0 ]; then
        return $(true)
    fi

    return $(false)
    #continue
}


command_exists() {
        command -v "$@" > /dev/null 2>&1
}


trim() {
    local var="$*"

    # 删除开关空白字符
    var="${var#"${var%%[![:space:]]*}"}"
    # 删除结尾空白字符
    var="${var%"${var##*[![:space:]]}"}"   
    echo "$var"
}


# 特殊处理按月索引，通过判断月份拼接日期，忽略闰年
# 格式: myindex-2022-10  myindex-202210
# 索引返回格式: myindex-20221031
handler_index_by_month() {
    local idx=$1

    if [[ "${idx}" =~ "-" ]]; then
        year_month_of_index="${idx#*-}"
        index_prefix="${idx%%-*}"
        if [[ "${year_month_of_index}" =~ "-" ]]; then
            month_of_index="${idx##*-}"
        else
            month_of_index="${year_month_of_index:(-2):2}}"
        fi

        case "${month_of_index}" in
            "2" | "02")
                if [[ "${year_month_of_index}" =~ "-" ]]; then
                    temp_year_month_of_index=$(echo "$year_month_of_index" | tr -d -)
                    echo "${index_prefix}-${temp_year_month_of_index}28"
                    #echo "${idx}-28"
                else
                    echo "${idx}28"
                fi
                ;;
            "4" | "04" | "6" | "06" | "9" | "09" | "11")
                if [[ "${year_month_of_index}" =~ "-" ]]; then
                    temp_year_month_of_index=$(echo "$year_month_of_index" | tr -d -)
                    echo "${index_prefix}-${temp_year_month_of_index}30"
                    #echo "${idx}-30"
                else
                    echo "${idx}30"
                fi
                ;;
            "1" | "01" | "3" | "03" | "5" | "05" | "7" | "07" | "8" | "08" | "10" | "12")
                if [[ "${year_month_of_index}" =~ "-" ]]; then
                    temp_year_month_of_index=$(echo "$year_month_of_index" | tr -d -)
                    echo "${index_prefix}-${temp_year_month_of_index}31"
                    #echo "${idx}-31"
                else
                    echo "${idx}31"
                fi
                ;;
            *)
                log warn "传入参数错误，请检查索引${idx}格式是否正确"
                exit 2
        esac
    fi

    #echo ""
}

# 合并索引segment减少heap内存占用
# TBD
forcemerge_index_segment () {
    local IDX=$1

    if ! command_exists jq; then
        echo "command jq not exist" | tee -a $LOGFILE
        exit 1
    fi

    for index in ${IDX[*]}; do
        if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
            INDEXES=$(curl -s -X GET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        else
            INDEXES=$(curl -s -u ${USERNAME}:${PASSWD} -X GET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        fi

        YESTERDAY_TIMESTAMP=$(date -d $(date -d "-${DAYS} days" "+%Y%m%d") "+%s")

        for index in ${INDEXES}; do
            indexDate=`echo ${index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
            indexTime=`date -d "${indexDate}" "+%s"`

            # 差值大于等于0则执行强制合并segemnt
            is_force_merge ${indexTime} ${YESTERDAY_TIMESTAMP}
            if [ $? -eq 0 ]; then
                if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
                    MERGE_RESULT=$(curl -s -X POST http://$ESIP:$ESPORT/${index}/_forcemerge?max_num_segments=1)
                else
                    MERGE_RESULT=$(curl -u ${USERNAME}:${PASSWD} -s -X POST http://$ESIP:$ESPORT/${index}/_forcemerge?max_num_segments=1)
                fi

                echo "`date "+%F %T"`  merage result is ${MERGE_RESULT}" >> $LOGFILE
                if [ `echo ${MERGE_RESULT} | jq -r '._shards.failed' ` -eq 0 ]; then
                    echo "`date "+%F %T"` ${index} had already been meraged!" >> $LOGFILE
                else
                    echo "`date "+%F %T"` there is something wrong happend when meraged ${index}" >> $LOGFILE
                fi
            else
                echo "`date "+%F %T"` ${index} no need merge." >> $LOGFILE
            fi
        done
    done
}


del_es_old_index() {
    local es_host="$1"
    local es_port="$2"
    local es_username="${3:-}"
    local es_password="${4:-}"
    local data_backup_dir="$5"

    # es有用户名和密码
    LIFECYCLE=$(date -d "$(date "+%Y%m%d") -$MAXLIFE days" "+%s")
    INDEXES=$(curl -s -u "${es_username}":"${es_password}" -XGET http://"${es_host}":"${es_port}"/_cat/indices | awk '{print $3}')
    #INDEXES=$(curl -s -XGET http://$ESIP:$ESPORT/_cat/indices | awk '{print $3}')

    for index in ${INDEXES}; do
        is_start_with_dot "${index}"
        if [ $? -ne 0 ]; then
            if [[ "${index}" =~ ^idp4.* ]]; then
                if ! verify_index_formats "${index}"; then
                    final_index=$(handler_index_by_month "${index}")
                    if [[ "X${final_index}" != "X" ]]; then
                        indexDate=`echo ${final_index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
                        indexTime=`date -d "${indexDate}" "+%s"`

                        is_delete ${indexTime} ${LIFECYCLE}
                        if [ $? -eq 0 ]; then
                            # 删除索引之前先备份数据
                            backup ${es_host} ${es_port} ${final_index} ${data_backup_dir} ${es_username} ${es_password}
                            delResult=`curl -s -u "${es_username}":"${es_password}" -XDELETE http://"${es_host}":"${es_port}"/${final_index}`
                            #delResult=`curl -s -XDELETE http://$ESIP:$ESPORT/${index}`
                            echo "`date "+%F %T"` delResult is ${delResult}" >> $LOGFILE

                            if [ `echo ${delResult} | grep 'acknowledged' | wc -l` -eq 1 ]; then
                                echo "`date "+%F %T"` ${final_index} had already been deleted!" >> $LOGFILE
                            else
                                echo "`date "+%F %T"` there is something wrong happend when deleted ${final_index}, pleas check again." >> $LOGFILE
                            fi
                        #else
                        #    log info "-----------测试是否能正确获取按月索引: ${final_index} -------------------"
                        fi
                    fi
                fi
            fi
        fi
    done
}


#main() {
#    for index in ${INDICES}; do
#        backup ${ES_HOST} ${ES_PORT} ${index} ${BACKUP_DIR}
#    done
#    enterWorkspace ${BACKUP_DIR}
#    compressFile ${FILENAME} ${compress_mode} ${timestamp} ${CompressExtName}
#    clean_gz_file ${BACKUP_DIR}
#    migration_to_qcloud_cos
#    delete_old_data ${BACKUP_DIR}
#}

# ####### entrypoint 
del_es_old_index "${ESIP}" "${ESPORT}" "${ES_USERNAME}" "${ES_PASSWORD}" "${BACKUP_DIR}"



