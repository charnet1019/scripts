#!/usr/bin/env python
#-*- coding:utf-8 -*-
##########################################################
#
# Copyright (2017-10-21, )
#
# Author: charnet1019@163.com
# Last modified:2017-10-28 22:00
# Description: 
#
##########################################################
 
import requests
import json
import traceback

# 仓库地址
repo_ip = 'registry'
repo_port = 5000
# 获取指定数量的镜像
COUNT=3000

def isNotEmpty(s):
    return s and len(s.strip()) > 0

def getImagesNames(repo_ip,repo_port):
    docker_images = []
    try:
        url = "http://" + repo_ip + ":" + str(repo_port) + "/v2/_catalog?n=" + str(COUNT)
        res =requests.get(url).content.strip()
        res_dic = json.loads(res)
        images_type = res_dic['repositories']
        for i in images_type:
            url2 = "http://" + repo_ip + ":" + str(repo_port) +"/v2/" + str(i) + "/tags/list"
            res2 =requests.get(url2).content.strip()
            res_dic2 = json.loads(res2)
            name = res_dic2['name']
            # tags = res_dic2[filter(isNotEmpty,'tags')]
            tags = res_dic2['tags']

            if tags not in [None]:
                for tag in tags:
                    if repo_port == 80 or repo_port == 443:
                        docker_name = str(repo_ip) + "/" + name + ":" + tag
                    else:
                        docker_name = str(repo_ip) + ":" + str(repo_port) + "/" + name + ":" + tag
                    docker_images.append(docker_name)
                    print(docker_name)
    except:
        traceback.print_exc()
    return docker_images
   

if __name__ == '__main__':
    getImagesNames(repo_ip, repo_port)
