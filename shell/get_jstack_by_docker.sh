#!/bin/bash

SVC_NAME=$1
DATETIME_FORMAT=$(date "+%F_%H-%M-%S")

STATIC_SRV="10.10.11.xx"

get_jstack_log() {
    CONTAINER_ID=$(docker ps | grep -w ${SVC_NAME} | grep -v "rancher/pause" | grep -v "grep" | awk '{print $1}')
    docker exec -it ${CONTAINER_ID} jstack -l 1 > /tmp/$(hostname)_${SVC_NAME}_${DATETIME_FORMAT}.txt
    scp -o StrictHostKeyChecking=no /tmp/$(hostname)_${SVC_NAME}_${DATETIME_FORMAT}.txt ${STATIC_SRV}:/opt/sharedfile/jstack_logs/
    #rm -f /tmp/$(hostname)_${SVC_NAME}_${DATETIME_FORMAT}.txt
}

if [ $# -lt 1 ]; then
    echo "need a pod name"
    echo "Usage: $0 POD_NAME"
    exit 1
fi

get_jstack_log



