#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import time
import json
import requests
import re


reload(sys)
sys.setdefaultencoding('utf8')


# 发送信息
def send_message(send_url, msg):
    values = {
        "msgtype": "text",
        "text": {"content": msg},
    }
    msg = json.dumps(values)
    resp = requests.post(url=send_url, data=msg, headers={'Content-Type': 'application/json'})
    
    if (json.loads(resp.text)['errcode'] == 0):
        return True
    
    return False


if __name__ == '__main__':
    wx_webhook_url = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=320648c1-xxxxxxxxxxxxx-fa2ef73564e4'

    #req = json.dumps(sys.argv[1])
    #data = json.loads(req.replace('\n', ''))
    
    data = json.loads(sys.argv[1].replace('\n', ''))
    
    msg = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + " 有待处理的工单 " + "#" + str(data["id"]) + data["title"] + "，请及时进行处理."
    # 发送给企业微信机器人
    send_message(wx_webhook_url, msg)
    
    
    
    
