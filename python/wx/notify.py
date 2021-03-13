#!/usr/bin/python
# -*- coding: utf-8 -*-

import time
from flask import Flask, request
import requests
import json
import logging
import sys

import setproctitle


reload(sys)
sys.setdefaultencoding('utf8')

app = Flask(__name__)

LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"
DATE_FORMAT = "%m/%d/%Y %H:%M:%S %p"
logging.basicConfig(filename='/opt/phoneCall/myphone.log', level=logging.DEBUG, format=LOG_FORMAT, datefmt=DATE_FORMAT)


@app.route('/iot-frontend/alert', methods=['POST'])
def iot_frontend_alert():
    wx_robot_url = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=320ffffffffffffffffff'
    try:
        data = json.loads(request.data)
        print(json.dumps(data, encoding="UTF-8", ensure_ascii=False))
      
        alerts = data['alerts']
      
        for i in alerts:
            alert_status = i.get('status')

            if alert_status == 'firing':
                env = i.get('labels')['env']
                app_type = i.get('labels')['app']
                instance = i.get('labels')['instance']
                str_msg = env + '环境' + "物联网" + app_type + ': ' + instance + ' 异常, 请检查相关服务.'
                values = {
                    "msgtype": 'text',
                    "text": {'content': str_msg},
                }
                msg = json.dumps(values)
                headers={'Content-Type':'application/json'}
                resp = requests.post(url=wx_robot_url, data=msg, headers=headers)
                print(resp)
                print(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' 前端服务异常调用')
    except Exception as e:
      print(e)

    return "ok"


# devops_alive
@app.route('/devops_alive/alert', methods=['POST'])
def devops_alive_alert():
    wx_robot_url = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=32064yyyyyyyyyyyyyyyyyyyyy'
    try:
        data = json.loads(request.data)
        print(json.dumps(data, encoding="UTF-8", ensure_ascii=False))
      
        alerts = data['alerts']
      
        for i in alerts:
            alert_status = i.get('status')

            if alert_status == 'firing':
                env = i.get('labels')['env']
                app_type = i.get('labels')['app']
                instance = i.get('labels')['instance']
                str_msg = env + '环境' + app_type + ': ' + instance + ' 异常, 请检查相关服务.'
                values = {
                    "msgtype": 'text',
                    "text": {'content': str_msg},
                }
                msg = json.dumps(values)
                headers={'Content-Type':'application/json'}
                resp = requests.post(url=wx_robot_url, data=msg, headers=headers)
                print(resp)
                print(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' 前端服务异常调用')
    except Exception as e:
      print(e)

    return "ok"


# aliyun_vpn
@app.route('/vpn/alert', methods=['POST'])
def vpn_alert():
    wx_robot_url = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=320648c1-xxxxxxxxxxxxxxxxxx'
    try:
        data = json.loads(request.data)
        #print(json.dumps(data, encoding="UTF-8", ensure_ascii=False))
        #logging.info(json.dumps(data, encoding="UTF-8", ensure_ascii=False))
      
        alerts = data['alerts']
            
        for i in alerts:
            alert_status = i.get('status')
                
            if alert_status == 'firing':
                env = i.get('labels')['env']
                #app_type = i.get('labels')['app'] 
                #instance = i.get('labels')['ping']
                desc = i.get('annotations')['description']
                #str_msg = env + '访问阿里云vpn端点' + '(' + instance + ')' + '网络延时超过500ms，' + '请尽快检查网络。'
                str_msg = desc
                values = {
                    "msgtype": 'text',
                    "text": {'content': str_msg},
                }
                msg = json.dumps(values)
                logging.info('msg: ' + msg)
                headers={'Content-Type':'application/json'}
                resp = requests.post(url=wx_robot_url, data=msg, headers=headers)
                #print(resp)
                #print(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' 前端服务异常调用')
                logging.info(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' 阿里云vpn异常')
    except Exception as e:
      print(e)

    return "ok"

if __name__ == '__main__':
    #logging.info('开始监听事件')
    setproctitle.setproctitle('phonecall')
    app.run(debug=True, host='0.0.0.0', port=8888)






