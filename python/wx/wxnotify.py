#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import requests

class WeChat(object):
    def __init__(self, totag, corpid, secret, agentid):
        self.url = "https://qyapi.weixin.qq.com"
        self.totag = totag
        self.corpid = corpid
        self.secret = secret
        self.agentid = agentid

    # 获取企业微信的 access_token
    def access_token(self):
        url_arg = '/cgi-bin/gettoken?corpid={id}&corpsecret={crt}'.format(
            id=self.corpid, crt=self.secret)
        url = self.url + url_arg
        response = requests.get(url=url)
        text = response.text
        self.token = json.loads(text)['access_token']

    # 构建消息格式
    def messages(self, msg):
        values = {
            "totag": self.totag,
            "msgtype": 'text',
            "agentid": self.agentid,
            "text": {'content': msg},
            "safe": 0
        }
        # python 3
        # self.msg = (bytes(json.dumps(values), 'utf-8'))
        # python 2
        self.msg = json.dumps(values)

    # 发送信息
    def send_message(self, msg):
        self.access_token()
        self.messages(msg)

        send_url = '{url}/cgi-bin/message/send?access_token={token}'.format(
            url=self.url, token=self.token)
        response = requests.post(url=send_url, data=self.msg)
        errcode = json.loads(response.text)['errcode']

        if errcode == 0:
            print('Succesfully')
        else:
            print('Failed')



if __name__ == '__main__':
   totag = '666'
   corpid = 'ww7d75xxxxxx1ab5f'
   secret = 'jgWCtixxxxxxxxxxx7cuSSrVApd8PJq7W0'
   agentid = '10xxxxxxxxxx'
   msg = 'hello world!'

   wx = WeChat(totag, corpid, secret, agentid)
   wx.send_message(msg)





