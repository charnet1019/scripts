#!/usr/bin/env python
# -*- coding: utf-8 -*-

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
   wx_webhook_url = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=225f6145-b6b0-43ec-84de-xxxxxxxxxxx'
   msg = 'hello world!'

   send_message(wx_webhook_url, msg)





