#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''
实现调用钉钉互动服务窗api接口发送告警信息
'''

import time
import requests
import json
import uuid
import sys
import re
import logging
from platform import python_version_tuple

from flask import Flask, request, jsonify

# 互动窗文档说明
# https://developers.dingtalk.com/document/app/group-messaging-apis-for-interactive-service-windows

PY2 = python_version_tuple()[0] == '2'
PY3 = python_version_tuple()[0] == '3'

app = Flask(__name__)

class CheckJSON():
    def getkeys(self, data):
        keys_all_list = []

        def getkeys(data):
            if (type(data) == type({})):
                keys = data.keys()
                for key in keys:
                    value = data.get(key)
                    if (type(value) != type({}) and type(value) != type([])):
                        keys_all_list.append(key)
                    elif (type(value) == type({})):
                        keys_all_list.append(key)
                        getkeys(value)
                    elif (type(value) == type([])):
                        keys_all_list.append(key)
                        for para in value:
                            if (type(para) == type({})
                                    or type(para) == type([])):
                                getkeys(para)
                            else:
                                keys_all_list.append(para)

        getkeys(data)
        return keys_all_list

    def is_exists(self, data, tagkey):
        if (type(data) != type({})):
            print('Please input a json!')
        else:
            key_list = self.getkeys(data)
            for key in key_list:
                if (key == tagkey):
                    return True

        return False


def verify_datetime(datetime_):
    pattern = r'((?!0000)[0-9]{4}-((0[1-9]|1[0-2])-(0[1-9]|1[0-9]|2[0-8])|(0[13-9]|1[0-2])-(29|30)|(0[13578]|1[02])-31)|([0-9]{2}(0[48]|[2468][048]|[13579][26])|(0[48]|[2468][048]|[13579][26])00)-02-29) (20|21|22|23|[0-1]\d):[0-5]\d:[0-5]\d$'
    if re.match(pattern, datetime_):
        return True

    return False


def format_date_tz(raw_date):
    date = raw_date.replace('T', ' ').replace('Z', '').split('.')[0]
    if not verify_datetime(date):
        raise ValueError(raw_date, date)
    return date


def trim(docstring):
    if not docstring:
        return ''
    # Convert tabs to spaces (following the normal Python rules)
    # and split into a list of lines:
    lines = docstring.expandtabs().splitlines()
    # Determine minimum indentation (first line doesn't count):

    indent = sys.maxsize

    for line in lines[1:]:
        stripped = line.lstrip()
        if stripped:
            indent = min(indent, len(line) - len(stripped))
    # Remove indentation (first line is special):
    trimmed = [lines[0].strip()]
    if indent < sys.maxsize:
        for line in lines[1:]:
            trimmed.append(line[indent:].rstrip())
    # Strip off trailing and leading blank lines:
    while trimmed and not trimmed[-1]:
        trimmed.pop()
    while trimmed and not trimmed[0]:
        trimmed.pop(0)
    # Return a single string:
    return '\n'.join(trimmed)


def get_message():
    check_json = CheckJSON()
    try:
        if not check_json.is_exists(json.loads(request.data), 'topic'):
            data = json.loads(request.data)
            # print(json.dumps(data, encoding="UTF-8", ensure_ascii=False))

            alerts = data['alerts']
            # element_lens = len(alerts)
            # print(element_lens)

            msg_list = []
            str_msg = ''
            num = 0
            while num < len(alerts):
                alert_status = alerts[num].get('status')

                if alert_status == 'firing':
                    env = alerts[num].get('labels')['env']  # 告警环境
                    alert_object = alerts[num].get('labels')['app']  # 告警对象
                    alert_name = alerts[num].get('labels')['alertname']  # 告警主题
                    alert_desc = alerts[num].get('annotations')['description']  # 告警详情
                    alert_starts_at = format_date_tz(alerts[num].get('startsAt'))  # 触发时间
                    alert_status = alerts[num].get('status')  # 告警状态
    
                    str_msg = '''
                        =====================start=====================
                        告警环境: {0}
                        告警对象: {1}
                        告警主题: {2}
                        告警详情: {3}
                        触发时间: {4}
                        告警状态: {5}
                        ======================end======================
                    '''.format(env, alert_object, alert_name, alert_desc, alert_starts_at, alert_status)
                elif alert_status == 'resolved':
                    env = alerts[num].get('labels')['env']  # 告警环境
                    alert_object = alerts[num].get('labels')['app']  # 告警对象
                    alert_name = alerts[num].get('labels')['alertname']  # 告警主题
                    alert_desc = alerts[num].get('annotations')['description']  # 告警详情
                    alert_starts_at = format_date_tz(alerts[num].get('startsAt'))  # 触发时间
                    alert_ends_at = format_date_tz(alerts[num].get('endsAt'))  # 恢复时间
                    alert_status = alerts[num].get('status')  # 告警状态

                    str_msg = '''
                        =====================start=====================
                        告警环境: {0}
                        告警对象: {1}
                        告警主题: {2}
                        告警详情: {3}
                        触发时间: {4}
                        恢复时间: {5}
                        告警状态: {6}
                        ======================end======================
                    '''.format(env, alert_object, alert_name, alert_desc, alert_starts_at, alert_ends_at, alert_status)

                msg_list.append(str_msg)
                # print(msg_list)
                str_msg = ''.join(msg_list)
                # print(str_msg)
                num += 1
                
            return trim(str_msg)
        else:
            data = json.loads(request.data)
            # print(json.dumps(data, encoding="UTF-8", ensure_ascii=False))
            alerts = data['alerts']

            msg_list = []
            str_msg = ''
            num = 0

            while num < len(alerts):
                alert_status = alerts[num].get('status')

                if alert_status == 'firing':
                    env = alerts[num].get('labels')['env']  # 告警环境
                    alert_object = alerts[num].get('labels')['app']  # 告警业务
                    alert_name = alerts[num].get('labels')['alertname']  # 告警主题
                    alert_group = alerts[num].get('annotations')['group']  # 告警消息组
                    alert_topic = alerts[num].get('annotations')['topic']  # 告警topic
                    alert_desc = alerts[num].get('annotations')['description']  # 告警详情
                    alert_starts_at = format_date_tz(alerts[num].get('startsAt'))  # 触发时间
                    alert_status = alerts[num].get('status')  # 告警状态

                    str_msg = '''
                        告警环境: {0}
                        告警业务: {1}
                        告警主题: {2}
                        告警消息组: {3}
                        告警Topic: {4}
                        告警详情: {5}
                        触发时间: {6}
                        告警状态: {7}
                    '''.format(env, alert_object, alert_name, alert_group,
                               alert_topic, alert_desc, alert_starts_at,
                               alert_status)
                elif alert_status == 'resolved':
                    env = alerts[num].get('labels')['env']  # 告警环境
                    alert_object = alerts[num].get('labels')['app']  # 告警业务
                    alert_name = alerts[num].get('labels')['alertname']  # 告警主题
                    alert_group = alerts[num].get('annotations')['group']  # 告警消息组
                    alert_topic = alerts[num].get('annotations')['topic']  # 告警topic
                    alert_desc = alerts[num].get('annotations')['description']  # 告警详情
                    alert_starts_at = format_date_tz(alerts[num].get('startsAt'))  # 触发时间
                    alert_ends_at = format_date_tz(alerts[num].get('endsAt'))  # 恢复时间
                    alert_status = alerts[num].get('status')  # 告警状态

                    str_msg = '''
                        告警环境: {0}
                        告警业务: {1}
                        告警主题: {2}
                        告警消息组: {3}
                        告警Topic: {4}
                        告警详情: {5}
                        触发时间: {6}
                        恢复时间: {7}
                        告警状态: {8}
                    '''.format(env, alert_object, alert_name, alert_group,
                               alert_topic, alert_desc, alert_starts_at,
                               alert_ends_at, alert_status)

                msg_list.append(str_msg)
                # print(msg_list)
                str_msg = ''.join(msg_list)
                # print(str_msg)
                num += 1

            return trim(str_msg)
    except Exception as e:
        logging.error(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + e)
        print(e)


def get_token(appkey, appsecret):
    url = 'https://oapi.dingtalk.com/gettoken?appkey={0}&appsecret={1}'.format(appkey, appsecret)
    req = requests.get(url)
    token = json.loads(req.text)['access_token']
    expires = json.loads(req.text)['expires_in'] + time.time()

    # print(token)
    return token, expires


def verify_token(timestamp):
    '''
    return: 
        1 token未过期
    '''
    # 过期时间2小时
    if time.time() - timestamp < 7200:
        return True

    return False


def get_unionid(appkey, appsecret):
    header = {"Content-Type": "application/json", "Charset": "UTF-8"}

    token, expires_in = get_token(appkey, appsecret)
    url = 'https://oapi.dingtalk.com/topapi/serviceaccount/list?access_token={0}'.format(token)
    req = requests.post(url, headers=header)

    print(json.dumps(req.json(), ensure_ascii=False))
    print(req.json()['items'][4]['unionid'])
    unionid = req.json()['items'][4]['unionid']

    return unionid


# def send_ding_message(unionid, token, userlist):
@app.route('/alarm/dingtalk/send', methods=['POST'])
def send_ding_message():
    global access_token
    global daedline_time

    # print(daedline_time)
    # print(access_token)
    if verify_token(daedline_time):
        # print('进入if')
        send_url = 'https://oapi.dingtalk.com/topapi/message/mass/send?access_token={0}'.format(access_token)
        suuid = uuid.uuid1().hex
        # 请求头部
        header = {"Content-Type": "application/json", "Charset": "UTF-8"}

        msg = get_message()
        print(msg)
        payload = {
            "unionid": dingtalk_unionid,
            "is_to_all": "false",
            "msg_type": "text",
            "text_content": msg,
            "uuid": suuid,
            "userid_list": notify_users
        }

        # 对请求的数据进行json封装
        message_json = json.dumps(payload)
        # print(message_json)
        requests.DEFAULT_RETRIES = 3
        # 发送请求
        info = requests.post(url=send_url, data=message_json, headers=header)
        # 打印返回结果
        print(info.text)
        if (json.loads(info.text)['errcode'] == 0):
            return jsonify({
                'retval': 0,
                'msg': 'ok',
                'description': '告警消息发送成功'
            })

        logging.error(
            time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) +
            ' 钉钉接口调用失败 ' + json.loads(info.text)['sub_msg'])
        return jsonify({
            'retval': json.loads(info.text)['sub_code'],
            'msg': json.loads(info.text)['sub_msg'],
            'description': '告警消息发送失败'
        })
    else:
        # print('进入else')
        access_token, daedline_time = get_token(dingtalk_appkey, dingtalk_appsecret)
        logging.info(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' token过期,重新获取token为 ' + access_token)
        send_url = 'https://oapi.dingtalk.com/topapi/message/mass/send?access_token={0}'.format(access_token)
        suuid = uuid.uuid1().hex
        # 请求头部
        header = {"Content-Type": "application/json", "Charset": "UTF-8"}

        msg = get_message()
        payload = {
            "unionid": dingtalk_unionid,
            "is_to_all": "false",
            "msg_type": "text",
            "text_content": msg,
            "uuid": suuid,
            "userid_list": notify_users
        }

        # 对请求的数据进行json封装
        message_json = json.dumps(payload)
        requests.DEFAULT_RETRIES = 3
        # 发送请求
        info = requests.post(url=send_url, data=message_json, headers=header)
        # 打印返回结果
        # print(info.text)
        if (json.loads(info.text)['errcode'] == 0):
            return jsonify({
                'retval': 0,
                'msg': 'ok',
                'description': '告警消息发送成功'
            })

        logging.error(
            time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) +
            ' 钉钉接口调用失败 ' + json.loads(info.text)['sub_msg'])
        return jsonify({
            'retval': json.loads(info.text)['sub_code'],
            'msg': json.loads(info.text)['sub_msg'],
            'description': '告警消息发送失败'
        })


if __name__ == "__main__":
    # 运维团队互动窗口
    dingtalk_appkey = 'dingxfmmixxxxxxxxxxx'
    dingtalk_appsecret = 'DQ-_6Wql7YtYQxxxxxxxxxxxxxxxxvhdp4uCklz_o5DYAHgL1-k9TUlW2M--'
    dingtalk_unionid = 'niSVYiicxxxxxxxxxxxGUgiEiE'


    # 告警接收人列表
    notify_users = '20xxxxxx, 20xxxxxxx, 20xxxxxx'

    LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"
    DATE_FORMAT = "%m/%d/%Y %H:%M:%S %p"
    logging.basicConfig(filename='/opt/monitor/dingtalk.log', level=logging.DEBUG, format=LOG_FORMAT, datefmt=DATE_FORMAT)

    # print(get_unionid(dingtalk_appkey, dingtalk_appsecret))
    print('---------------- 启动app前')
    global access_token, daedline_time
    access_token, daedline_time = get_token(dingtalk_appkey, dingtalk_appsecret)
    print(access_token)
    print(daedline_time)
    app.run(debug=True, host='0.0.0.0', port=8888)
    
    
    
    
    
