#/bin/bash

# Author: pengchanghong
# Date: 20190313

# 0 0 * * * /bin/bash /usr/local/exueyun/elk/del_index.sh &> /dev/null

set -e

ESIP=192.168.129.3
ESPORT=9200
# 如果es没有用户名则置为空
USERNAME=elastic
# 如果es没有密码则置为空
PASSWD=hJ1I7BOzw
# 保留最近N天的日志
MAXLIFE=20

# 保留最近N天的ELK系统监控日志
MONITOR_MAXLIFE=3

# 强制合并几天前的索引
DAYS=1

# ELK系统索引
MONITOR_INDEX=(.monitoring-beats
.monitoring-es
.monitoring-kibana
.monitoring-logstash
.watcher-history
)

INDEX=(logstash_agent_web
logstash_api_agent
logstash_api_attendance
logstash_api_auth
logstash_api_boss
)

LOGFILE="/var/log/elkDel.log"

[ ! -f $LOGFILE ] && touch $LOGFILE


is_delete(){
    if [ $(($1-$2)) -gt 0 ]; then
        return 1
    fi

    return 0
}


is_force_merge() {
    if [ $(($2-$1)) -ge 0 ]; then
        return 0
    fi

    #return 1
    continue
}


command_exists() {
        command -v "$@" > /dev/null 2>&1
}

# 删除业务自定义索引
del_custome_index() {
    local IDX=$1

    for index in ${IDX[*]}; do
        if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
            INDEXES=$(curl -s -X GET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        else
            INDEXES=$(curl -s -u ${USERNAME}:${PASSWD} -X GET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        fi

        LIFECYCLE=$(date -d "$(date "+%Y%m%d") -$MAXLIFE days" "+%s")

        for index in ${INDEXES}; do
            indexDate=`echo ${index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
            indexTime=`date -d "${indexDate}" "+%s"`

            is_delete ${indexTime} ${LIFECYCLE}
            if [ $? -eq 0 ]; then
                if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
                    delResult=`curl -s -X DELETE http://$ESIP:$ESPORT/${index}`
                else
                    delResult=`curl -s -u ${USERNAME}:${PASSWD} -X DELETE http://$ESIP:$ESPORT/${index}`
                fi

                echo "`date "+%F %T"` delResult is ${delResult}" >> $LOGFILE
                if [ `echo ${delResult} | grep 'acknowledged' | wc -l` -eq 1 ]; then
                    echo "`date "+%F %T"` ${index} had already been deleted!" >> $LOGFILE
                else
                    echo "`date "+%F %T"` there is something wrong happend when deleted ${index}" >> $LOGFILE
                fi
            fi
        done
    done
}


# 删除ELK系统监控索引
del_monitor_index() {
    local IDX=$1

    for index in ${IDX[*]}; do
        if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
            INDEXES=$(curl -s -X GET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        else
            INDEXES=$(curl -s -u ${USERNAME}:${PASSWD} -X GET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        fi

        LIFECYCLE=$(date -d "$(date "+%Y%m%d") -${MONITOR_MAXLIFE} days" "+%s")

        for index in ${INDEXES}; do
            indexDate=`echo ${index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
            indexTime=`date -d "${indexDate}" "+%s"`

            is_delete ${indexTime} ${LIFECYCLE}
            if [ $? -eq 0 ]; then
                if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
                    delResult=`curl -s -X DELETE http://$ESIP:$ESPORT/${index}`
                else
                    delResult=`curl -s -u ${USERNAME}:${PASSWD} -X DELETE http://$ESIP:$ESPORT/${index}`
                fi

                echo "`date "+%F %T"` delResult is ${delResult}" >> $LOGFILE
                if [ `echo ${delResult} | grep 'acknowledged' | wc -l` -eq 1 ]; then
                    echo "`date "+%F %T"` ${index} had already been deleted!" >> $LOGFILE
                else
                    echo "`date "+%F %T"` there is something wrong happend when deleted ${index}" >> $LOGFILE
                fi
            fi
        done
    done
}


# 合并索引segment减少heap内存占用
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

        #LIFECYCLE=$(date -d "$(date "+%Y%m%d") -${MONITOR_MAXLIFE} days" "+%s")
        YESTERDAY_TIMESTAMP=$(date -d $(date -d "-${DAYS} days" "+%Y%m%d") "+%s")
        echo ${YESTERDAY_TIMESTAMP=$}

        for index in ${INDEXES}; do
            indexDate=`echo ${index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
            indexTime=`date -d "${indexDate}" "+%s"`

            # 差值大于等于0则执行强制合并segemnt
            is_force_merge ${indexTime} ${YESTERDAY_TIMESTAMP}
            if [ $? -eq 0 ]; then
                if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
                    #delResult=`curl -s -X DELETE http://$ESIP:$ESPORT/${index}`
                    MERGE_RESULT=$(curl -s -X POST http://$ESIP:$ESPORT/${index}/_forcemerge?max_num_segments=1)
                else
                    #delResult=`curl -s -u ${USERNAME}:${PASSWD} -X DELETE http://$ESIP:$ESPORT/${index}`
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


# ##### main
del_custome_index "${INDEX[*]}"
del_monitor_index "${MONITOR_INDEX[*]}"
forcemerge_index_segment "${INDEX[*]}"

