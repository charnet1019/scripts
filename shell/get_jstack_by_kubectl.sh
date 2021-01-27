#!/bin/bash

# 根据container id获取指定pod的堆栈信息

SVC_NAME=$1
POD_IP=$2
KUBECONFIG=$3

REMOTE_SRV="10.10.10.64"
REMOTE_SRV_PATH="/data/jstack_logs"
REMOTE_SRV_URL="${REMOTE_SRV}:${REMOTE_SRV_PATH}"

NAMESPACE="my-service"

DATETIME_FORMAT=$(date "+%F_%H-%M-%S")

get_jstack_log() {
    #CONTAINER_ID=$(docker ps | grep -w ${SVC_NAME} | grep -v "rancher/pause" | grep -v "grep" | awk '{print $1}')
    CONTAINER_ID=$(kubectl get pod -n my-service --kubeconfig "${KUBECONFIG}" -o wide | grep -w "${SVC_NAME}" | grep "${POD_IP}" | awk '{print $1}')
    if [ -z "${CONTAINER_ID}" ]; then
        echo "没有找到对应的容器"
        exit 1
    fi
    #docker exec -it ${CONTAINER_ID} jstack -l 1 > /tmp/$(hostname)_${SVC_NAME}_${DATETIME_FORMAT}.txt
    kubectl exec -it "${CONTAINER_ID}" -n ${NAMESPACE} --kubeconfig "${KUBECONFIG}" -- jstack -l 1 > /tmp/"${SVC_NAME}"_"${DATETIME_FORMAT}".txt
    if [ $? -eq 0 ]; then
        echo "获取${SVC_NAME} jstack堆栈信息成功"
    else
        echo "获取${SVC_NAME} jstack堆栈信息失败"
        exit 1
    fi
    #/usr/bin/sshpass 'helloworld' scp -o 'StrictHostKeyChecking=no' "/tmp/$(hostname)_${SVC_NAME}_${DATETIME_FORMAT}.txt ${REMOTE_SRV_URL}"
    scp -o StrictHostKeyChecking=no /tmp/"${SVC_NAME}"_"${DATETIME_FORMAT}".txt ${REMOTE_SRV_URL}
    if [ $? -eq 0 ]; then
        echo "复制${SVC_NAME} jstack堆栈信息到${REMOTE_SRV_URL}成功"
    else
        echo "复制${SVC_NAME} jstack堆栈信息到${REMOTE_SRV_URL}失败"
        exit 1
    fi

    sleep 1
    rm -f /tmp/"${SVC_NAME}"_"${DATETIME_FORMAT}".txt

    echo -e "\n++++++++++++++++++++++ 访问地址 ++++++++++++++++++"
    echo -e "http://10.10.10.64:9999/jstack_logs/"${SVC_NAME}"_"${DATETIME_FORMAT}".txt\n"
}

if [ $# -lt 3 ]; then
    echo "Usage: $0 POD_NAME POD_IP KUBECONFIG"
    exit 1
fi

get_jstack_log



