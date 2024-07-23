#!/bin/bash

##########################################################
#
# Copyright (2017-10-21, )
#
# Author: charnet1019@163.com
# Last modified:2017-10-28 22:00
# Description: 
#
##########################################################

# 仓库地址
repo_ip='192.168.30.212'
repo_port=32768
# 获取指定数量的镜像
COUNT=1000

# 判断字符串是否非空
isNotEmpty() {
    [ -n "$1" ]
}

getImagesNames() {
    docker_images=()
    url="http://${repo_ip}:${repo_port}/v2/_catalog?n=${COUNT}"
    res=$(curl -s $url)
    images_type=$(echo $res | jq -r '.repositories[]')

    for i in $images_type; do
        url2="http://${repo_ip}:${repo_port}/v2/${i}/tags/list"
        res2=$(curl -s $url2)
        name=$(echo $res2 | jq -r '.name')
        tags=$(echo $res2 | jq -r '.tags[]')

        if isNotEmpty "$tags"; then
            for tag in $tags; do
                if [ "$repo_port" -eq 80 ] || [ "$repo_port" -eq 443 ]; then
                    docker_name="${repo_ip}/${name}:${tag}"
                else
                    docker_name="${repo_ip}:${repo_port}/${name}:${tag}"
                fi
                docker_images+=("$docker_name")
                echo "$docker_name"
            done
        fi
    done
}

getImagesNames
