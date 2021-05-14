#!/usr/bin/python
# -*- coding: utf-8 -*-
'''
告警解除前仅告警一次
'''

from flask import Flask, request
import requests
import json


app = Flask(__name__)

flag = 1

@app.route('/phone/call', methods=['POST'])
def send():
    global flag

    try:
        url_test_api = 'http://dev.xxxx.com/api/phone/call/Alarm' 
        dict1 = dict()   #定义一个字典用来存放清理过后的数据
        data = json.loads(request.data)   #转换从alertmanager获得的json数据为dict类型

        #print(json.dumps(data, ensure_ascii=False))
        #print(json.dumps(data, encoding="UTF-8", ensure_ascii=False))
        alerts = data['alerts']           

        for i in alerts:
            info = i.get('annotations') 
            alert_status = i.get('status')

            #print(json.dumps(info))
            if flag == 1 and alert_status == 'firing':
                #alert_topic = info.get('topic')
                #alert_count = info.get('description').split(':')[1]
                dict1['content'] = info.get('topic')
                dict1['alarmCount'] = info.get('description').split(':')[1]
                #print(alert_topic)
                #print(alert_count)
                j = json.dumps(dict1)
                #print("json output", j)
                ## 调用api打阿里电话
                r = requests.post(url_test_api, data=j, headers={'Content-Type':'application/json'})
                ## 输出调用的api的返回信息，一般返回200
                #print("输出调用api返回结果")
                print(r)
                #print(r.text)
                #print("输出结果完毕。")
                flag = 0
            elif alert_status == 'resolved':
                flag = 1
    except Exception as e:
        print(e)
    return 'ok'


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8888)






