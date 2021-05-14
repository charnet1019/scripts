#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import time
import json
import requests


# 发送信息
def send_message(send_url, msg):
    values = {
        "msgtype": 'text',
        "text": {'content': msg},
    }
    msg = json.dumps(values)

    resp = requests.post(url=send_url, data=msg, headers={'Content-Type':'application/json'})
    print(resp)

    #if errcode == 0:
    #    print('Succesfully')
    #else:
    #    print('Failed')


if __name__ == '__main__':
   wx_webhook_url = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=4bxxxxxxxxxxxxxxxx5c'
   
   # ### 推送给微服务开发群
   msg = sys.argv[1] + ' 已于 ' + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' 发布, 请稍后验证改动内容.'
   #print(msg)
   send_message(wx_webhook_url, msg)





