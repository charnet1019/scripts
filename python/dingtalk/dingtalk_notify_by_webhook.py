#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
实现调用钉钉webhook接口发送构建信息
'''

import sys
import time
import hmac
import hashlib
import base64
import urllib.parse
import requests
import json



# 钉钉机器人文档说明
# https://developers.dingtalk.com/document/app/custom-robot-access?spm=ding_open_doc.document.0.0.6d9d28e1enu2F7#topic-2026027

def get_timestamp_sign(secret):
    timestamp = str(round(time.time() * 1000))
    secret_enc = secret.encode('utf-8')
    string_to_sign = '{}\n{}'.format(timestamp, secret)
    string_to_sign_enc = string_to_sign.encode('utf-8')
    hmac_code = hmac.new(secret_enc, string_to_sign_enc,
                digestmod=hashlib.sha256).digest()
    sign = urllib.parse.quote_plus(base64.b64encode(hmac_code))
    #print("timestamp: ", timestamp)
    #print("sign:", sign)
    return (timestamp, sign)


def get_signed_url(webhook, secret):
    timestamp, sign = get_timestamp_sign(secret)
    webhook = webhook + "&timestamp=" + timestamp + "&sign=" + sign
    return webhook

def get_webhook(webhook, secret, mode):

    if mode == 0: # only 敏感字
       webhook = webhook
    elif mode == 1 or  mode ==2 : # 敏感字和加签 或 # 敏感字+加签+ip
        webhook = get_signed_url(webhook, secret)
    else:
        webhook = ""
        print("error! mode:   ", mode ,"  webhook :  ", webhook)
    return webhook

def get_message(content):
    message = {
        "msgtype": "text",
        "text": { 
            "content": content
        }
    }
    #print(message)
    return message

def send_ding_message(webhook, secret, content):
    webhook = get_webhook(webhook, secret, 1) # 主要模式有 0 ： 敏感字 1：# 敏感字 +加签 3：敏感字+加签+IP
    #print("webhook: ", webhook)
    # 请求头部
    header = {
        "Content-Type": "application/json",
        "Charset": "UTF-8"
    }
    # 请求数据
    message = get_message(content)
    # 对请求的数据进行json封装
    message_json = json.dumps(message)
    # 发送请求
    info = requests.post(url=webhook, data=message_json, headers=header)
    # 打印返回结果
    print(info.text)


if __name__ == "__main__":
    # 运维团队机器人
    devops_robot_webhook ="https://oapi.dingtalk.com/robot/send?access_token=0c8e2f23e73fca9xxxxxxxxxxxxxxxxxxx"
    devops_robot_secret="SEC767ff0761242961b5be36e26b7525f0ff7261be4b9xxxxxxxxxxxxxxxxxx"

    notify_type = sys.argv[1]
    project_name = sys.argv[2]
    content = project_name + ' 已于 ' + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' 发布, 请稍后验证改动内容.'

    if notify_type == 'devops':
        send_ding_message(devops_robot_webhook, devops_robot_secret, content)
    else:
        print("不支持的robot类型")
        sys.exit()




