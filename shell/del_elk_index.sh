#/usr/bin/env bash

# Author: charnet1019
# Date: 20190313
# 删除不以点开头的索引

ESIP=172.18.10.11
ESPORT=19200
# 没有用户名和密码则留空
ES_USERNAME=
ES_PASSWORD=
#保留最近N天的日志
MAXLIFE=7

# 索引格式
# dev-qxy-2021.04.19

LOGFILE="/var/log/elkDel.log"

if [ ! -f $LOGFILE ]; then
    touch $LOGFILE
fi

is_delete(){
    if [ $(($1-$2)) -gt 0 ]; then
        return 1
    fi

    return 0
}

is_start_with_dot() {
    local str="$1"

    if [[ ${str} =~ ^\..* ]]; then
        return `true`
    fi

    return `false`
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
    local es_username="$3"
    local es_password="$4"

    if [ -n "${es_host}" -a -n "${es_port}" -a -z "${es_username:-}" -a -z "${es_password:-}" ]; then
        LIFECYCLE=$(date -d "$(date "+%Y%m%d") -$MAXLIFE days" "+%s")
        INDEXES=$(curl -s -XGET http://"${es_host}":"${es_port}"/_cat/indices | awk '{print $3}')

        for index in ${INDEXES}; do
            is_start_with_dot "${index}"
            if [ $? -ne 0 ]; then
                indexDate=`echo ${index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
                indexTime=`date -d "${indexDate}" "+%s"`
                
                echo $index

                is_delete ${indexTime} ${LIFECYCLE}
                if [ $? -eq 0 ]; then
                    delResult=`curl -s -XDELETE http://"${es_host}":"${es_port}"/${index}`
                    echo "`date "+%F %T"` delResult is ${delResult}" >> $LOGFILE

                    if [ `echo ${delResult} | grep 'acknowledged' | wc -l` -eq 1 ]; then
                        echo "`date "+%F %T"` ${index} had already been deleted!" >> $LOGFILE
                    else
                        echo "`date "+%F %T"` there is something wrong happend when deleted ${index}" >> $LOGFILE
                    fi
                fi
            fi
        done
    elif [ -n "${es_host}" -a -n "${es_port}" -a -n "${es_username}" -a -n "${es_password}" ]; then
        LIFECYCLE=$(date -d "$(date "+%Y%m%d") -$MAXLIFE days" "+%s")
        INDEXES=$(curl -s -u "${es_username}":"${es_password}" -XGET http://"${es_host}":"${es_port}"/_cat/indices | awk '{print $3}')
        #INDEXES=$(curl -s -XGET http://$ESIP:$ESPORT/_cat/indices | awk '{print $3}')

        for index in ${INDEXES}; do
            is_start_with_dot "${index}"
            if [ $? -ne 0 ]; then
                indexDate=`echo ${index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
                indexTime=`date -d "${indexDate}" "+%s"`
                
                #echo $index

                is_delete ${indexTime} ${LIFECYCLE}
                if [ $? -eq 0 ]; then
                    delResult=`curl -s -u "${es_username}":"${es_password}" -XDELETE http://"${es_host}":"${es_port}"/${index}`
                    #delResult=`curl -s -XDELETE http://$ESIP:$ESPORT/${index}`
                    echo "`date "+%F %T"` delResult is ${delResult}" >> $LOGFILE

                    if [ `echo ${delResult} | grep 'acknowledged' | wc -l` -eq 1 ]; then
                        echo "`date "+%F %T"` ${index} had already been deleted!" >> $LOGFILE
                    else
                        echo "`date "+%F %T"` there is something wrong happend when deleted ${index}" >> $LOGFILE
                    fi
                fi
            fi
        done
    else
        echo "`date "+%F %T"` Invalid parameter." >> $LOGFILE
    fi
}


# ####### entrypoint 
del_es_old_index "${ESIP}" "${ESPORT}" "${ES_USERNAME}" "${ES_PASSWOD}"


