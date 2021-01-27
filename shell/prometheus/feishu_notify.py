#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
实现调用飞书接口发送构建信息
'''

import sys
import time
import hmac
import base64
import json
import requests
from hashlib import sha256


#feishu_secret_key = 'CPuJEmOrPwJ6ItozABdpOb'
#timestamp = int(time.time())
#
#sign_string = str(timestamp) + "\n" + feishu_secret_key
#sign_key = base64.b64encode(hmac.new(sign_string, digestmod=sha256).digest())
#
#print(timestamp)
#print(sign_key)
##print(time.asctime(time.localtime(time.time())))
#print(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()))

def send_msg(project_name):
    feishu_webhook = 'https://open.feishu.cn/open-apis/bot/v2/hook/49c2a27b-eeea-425f-a818-1cxxxxxxxxxx'
    feishu_secret_key = 'CPuJEmOrPwJ6ItozABdpOb'
    timestamp = int(time.time())

    sign_string = str(timestamp) + "\n" + feishu_secret_key
    sign_key = base64.b64encode(hmac.new(sign_string, digestmod=sha256).digest())

    msg_dict = dict()
    
    msg_dict['msg_type'] = 'text'
    msg_dict['timestamp'] = timestamp
    msg_dict['sign'] = sign_key
    msg_dict['content'] = {'text': project_name + ' 已于 ' + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' 发布, 请稍后验证改动内容.'}

    #msg_j = json.dumps(msg_dict, encoding="UTF-8", ensure_ascii=False)
    msg_j = json.dumps(msg_dict)
    #print(msg_j)
    req = requests.post(feishu_webhook, data=msg_j, headers={'Content-Type':'application/json'})
    #print(req)
    #print(req.text)
    
    
    
if __name__ == '__main__':
    #print(sys.argv[1])
    project_name = sys.argv[1] 
    send_msg(project_name)
    




