#!/bin/bash

REDIS_REMOTE_HOST="10.10.5.6"
RDB_REMOTE_PATH="/opt/redis-4.0.8/dump.rdb"
RCT_CMD="/opt/monitor/redis-rdb-cli/bin/rct"

RDB_BASE_DIR="/opt/cron/redis_bigkey_5-6"
RDB_PATH="${RDB_BASE_DIR}/dump.rdb"
ANALYZE_RESULT_PATH="${RDB_BASE_DIR}/dump.mem"

DB_CMD="/opt/cron/mysql"
DB="iot_grafana"
DB_TABLE="redis_monitor_53_96"
DB_HOST="10.10.5.5"
DB_PORT="13306"
DB_USER="mysql"
DB_PASSWD="xxxxxxxx"




get_rdb_file() {
    host=$1
    rdb_file=$2
    local_dir=$3

    scp -o StrictHostKeyChecking=no ${host}:${rdb_file} ${local_dir}
}

# ### github url: https://github.com/leonchen83/redis-rdb-cli
#./rct -f mem -s /data/redis/dump.rdb -o ./dump.mem
analyze_bigkey() {
    rdb_file=$1
    bigkey_result=$2

    # ## 10KB
    #${RCT_CMD} -f mem -b 10240 -s ${rdb_file} -o ${bigkey_result}
    # ## 1MB
    ${RCT_CMD} -f mem -b 1048576 -s ${rdb_file} -o ${bigkey_result}
}


# #### main
get_rdb_file "${REDIS_REMOTE_HOST}" "${RDB_REMOTE_PATH}" "${RDB_BASE_DIR}"
analyze_bigkey "${RDB_PATH}" "${ANALYZE_RESULT_PATH}"

# ### 删除分析结果表头
#sed -i '1d' ${ANALYZE_RESULT_PATH}
sed -i '/len_largest_element/d' ${ANALYZE_RESULT_PATH}

a=(`cat ${ANALYZE_RESULT_PATH} | awk -F "," '{print $1}'`)
b=(`cat ${ANALYZE_RESULT_PATH} | awk -F "," '{print $2}'`)
c=(`cat ${ANALYZE_RESULT_PATH} | awk -F "," '{print $3}'`)
d=(`cat ${ANALYZE_RESULT_PATH} | awk -F "," '{print $4}'`)
e=(`cat ${ANALYZE_RESULT_PATH} | awk -F "," '{print $5}'`)
f=(`cat ${ANALYZE_RESULT_PATH} | awk -F "," '{print $6}'`)
j=(`cat ${ANALYZE_RESULT_PATH} | awk -F "," '{print $7}'`)


# ## 插入数据前先清空表
${DB_CMD} -h ${DB_HOST} -P ${DB_PORT} -u${DB_USER} -p${DB_PASSWD} ${DB} -e "TRUNCATE TABLE ${DB_TABLE};"

arr_len=(${#a[@]})
#echo ${arr_len}
for ((i = 0; i < ${arr_len}; i++)); do
    ${DB_CMD} -h ${DB_HOST} -P ${DB_PORT} -u${DB_USER} -p${DB_PASSWD} ${DB} -e "INSERT INTO  ${DB_TABLE} (db, key_type, key_name, size_in_bytes, encoding, num_elements, len_largest_element) values ('${a[$i]}','${b[$i]}','${c[$i]}','${d[$i]}','${e[$i]}','${f[$i]}','${j[$i]}');" 
done






