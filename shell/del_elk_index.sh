#/bin/bash

# Author: pengchanghong
# Date: 20190313

# 0 0 * * * /bin/bash /usr/local/ex/elk/del_index.sh &> /dev/null

ESIP=192.168.129.3
ESPORT=9200
# 如果es没有用户名则置为空
USERNAME=elastic
# 如果es没有密码则置为空
PASSWD=vIvVNKhJ1I7
# 保留最近N天的日志
MAXLIFE=90

# 保留最近N天的ELK系统监控日志
MONITOR_MAXLIFE=5

# ELK系统索引
MONITOR_INDEX=(.monitoring-beats
.monitoring-es
.monitoring-kibana
.monitoring-logstash
.watcher-history
)

INDEX=(logstash-agent_web
logstash-api_agent
logstash-api_attendance
)
LOGFILE="/var/log/elkDel.log"

[ ! -f $LOGFILE ] && touch $LOGFILE

is_delete(){
    if [ $(($1-$2)) -gt 0 ]; then
        return 1
    fi

    return 0
}


del_custome_index() {
    local IDX=$1

    for index in ${IDX[*]}; do
        if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
            INDEXES=$(curl -s -XGET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        else
            INDEXES=$(curl -s -u ${USERNAME}:${PASSWD} -XGET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        fi

        LIFECYCLE=$(date -d "$(date "+%Y%m%d") -$MAXLIFE days" "+%s")

        for index in ${INDEXES}; do
            indexDate=`echo ${index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
            indexTime=`date -d "${indexDate}" "+%s"`

            is_delete ${indexTime} ${LIFECYCLE}
            if [ $? -eq 0 ]; then
                if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
                    delResult=`curl -s -XDELETE http://$ESIP:$ESPORT/${index}`
                else
                    delResult=`curl -s -u ${USERNAME}:${PASSWD} -XDELETE http://$ESIP:$ESPORT/${index}`
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

del_monitor_index() {
    local IDX=$1

    for index in ${IDX[*]}; do
        if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
            INDEXES=$(curl -s -XGET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        else
            INDEXES=$(curl -s -u ${USERNAME}:${PASSWD} -XGET http://$ESIP:$ESPORT/_cat/indices?v | grep -w "$index" | awk '{print $3}')
        fi

        LIFECYCLE=$(date -d "$(date "+%Y%m%d") -${MONITOR_MAXLIFE} days" "+%s")

        for index in ${INDEXES}; do
            indexDate=`echo ${index} | awk -F- '{print $NF}' | sed 's/\./-/g'`
            indexTime=`date -d "${indexDate}" "+%s"`

            is_delete ${indexTime} ${LIFECYCLE}
            if [ $? -eq 0 ]; then
                if [[ X"${USERNAME}" = X"" || X"${PASSWD}" = X"" ]]; then
                    delResult=`curl -s -XDELETE http://$ESIP:$ESPORT/${index}`
                else
                    delResult=`curl -s -u ${USERNAME}:${PASSWD} -XDELETE http://$ESIP:$ESPORT/${index}`
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


# ##### main
del_custome_index "${INDEX[*]}"
del_monitor_index "${MONITOR_INDEX[*]}"
