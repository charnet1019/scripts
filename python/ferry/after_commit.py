#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import time
import json
import requests
import platform
import sqlite3

from requests.exceptions import RequestException


PY2 = platform.python_version_tuple()[0] < '3'
if PY2:
    reload(sys)
    sys.setdefaultencoding('utf8')


class MySqlite3():
    def __init__(self, path):
        SQL_CREATE_DATABASE = '''CREATE TABLE IF NOT EXISTS session
                              (id INTEGER PRIMARY KEY AUTOINCREMENT,
                              access_token           TEXT    NOT NULL,
                              timestamp INT NOT NULL,
                              create_time TimeStamp NOT NULL DEFAULT (datetime('now','localtime')));'''    

        self.db = sqlite3.connect(path)
        self.cursor = self.db.cursor()

        self.cursor.execute(SQL_CREATE_DATABASE)

    #def create_database(self):
    #    SQL_CREATE_DATABASE = '''CREATE TABLE IF NOT EXISTS session
    #                          (id INTEGER PRIMARY KEY AUTOINCREMENT,
    #                          access_token           TEXT    NOT NULL,
    #                          timestamp INT NOT NULL,
    #                          create_time TimeStamp NOT NULL DEFAULT (datetime('now','localtime')));'''
    #    self.cursor.execute(SQL_CREATE_DATABASE)

    def fetch_one(self):
        SQL_SELECT_DATA = 'SELECT access_token, timestamp from session'

        return self.cursor.execute(SQL_SELECT_DATA)

    def insert_one(self, access_token, timestamp):
        SQL_INSERT_ONE_STATEMENT = 'INSERT INTO SESSION (access_token, timestamp) VALUES (\'{}\', {})'.format(access_token, timestamp)
        try:
            self.cursor.execute(SQL_INSERT_ONE_STATEMENT)
            self.db.commit()
        except Exception as e:
            print('数据插入失败: ' + str(e))

    def update_one(self, access_token, timestamp):
        SQL_UPDATE_STAEMENT = 'UPDATE session set access_token = \'{}\', timestamp = {} where id=1'.format(access_token, timestamp)
        try:
            self.cursor.execute(SQL_UPDATE_STAEMENT)
            self.db.commit()
        except Exception as e:
            print('数据更新失败: ' + str(e))
    
    def close(self):
        self.cursor.close()
        self.db.close()
        

class WeChatAlerter():
    # required_options = frozenset(['wechat_corp_id','wechat_secret','wechat_agent_id', 'wechat_user_id'])

    def __init__(self, wechat_corp_id, wechat_secret, wechat_agent_id, wechat_user_id):
        self.corp_id = wechat_corp_id
        self.secret = wechat_secret
        self.agent_id = wechat_agent_id
        self.user_id = wechat_user_id
        self.access_token = ''
        self.timestamp = ''

    def get_token(self):
        get_token_url = 'https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid={0}&corpsecret={1}'.format(self.corp_id, self.secret)
        
        try:
            resp = requests.get(get_token_url)
            resp.raise_for_status()
        except RequestException as e:
            print("get access_token failed , stacktrace:%s" % e)

        token_json = resp.json()

        if 'access_token' not in token_json :
            raise Exception("get access_token failed , , the response is :%s" % resp.text())

        self.access_token = token_json['access_token']
        self.timestamp = int(time.time())  # 时间戳不精确

        # token = json.loads(resp.text)['access_token']
        # expires = json.loads(resp.text)['expires_in'] + time.time()

        # print(token)
        return self.access_token, self.timestamp

    @property
    def set_access_token(self, access_token):
        self.access_token = access_token

    @property 
    def set_timestamp(self, timestamp):
        self.timestamp = timestamp
    


    def send_msg(self, content, msg_type, token=None):
        if token:
            self.access_token = token
        send_url = 'https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token={}'.format(self.access_token)
        headers = {
            "Content-Type": "application/json", 
            "Charset": "UTF-8"
            }
        
        if msg_type == 'text':
            # 文本消息
            payload = {
                "touser": self.user_id and str(self.user_id) or '',          #用户账户
                'msgtype': msg_type,
                "agentid": self.agent_id,
                "text":{
                    "content": content
                   },
                "safe":"0"
            }
        elif msg_type == 'markdown':
            # markdown
            payload = {
                "touser": self.user_id and str(self.user_id) or '',
                'msgtype': msg_type,
                "agentid": self.agent_id,
                "markdown": {
                    "content": "您有待审批的代码上线申请,请及时处理\n" + 
                                            ">**事项详情**\n" + 
                                            ">环境: {0}\n".format(content['env']) +
                                            ">工单ID: {0}\n".format(content['id']) + 
                                            ">事项: <font color=\"info\">{0}</font>\n".format(content['title']) +
                                            ">申请者: {0}\n".format(content['applicant']) +
                                            ">\n" +
                                            ">日期: <font color=\"info\">{0}</font>\n".format(content['date']) +
                                            ">上线原因: <font color=\"comment\">{0}</font>\n".format(content['reason'])
                                            
                   },
                "enable_duplicate_check": 0
            }
        
        try:
            response = requests.post(send_url, data=json.dumps(payload), headers=headers)
            #print(response.text)
        except Exception as e:
            #print(e)
            raise Exception('消息改善失败: {}'.format(e))


def verify_token( timestamp):
    """判断token是否过期
    
    :param timestamp: token过期时间戳
    :type timestamp: int
    """
    # 过期时间2小时
    if int(time.time()) - timestamp <= 7200:
        return True

    return False


# ##################### main
if __name__ == '__main__':
    #DB_PATH = '/opt/ferry/backend/static/database/session.db'
    #DB_PATH = 'qywechat/session.db'
    DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), 'database/session.db')

    wechat_corp_id = 'wxxxxxxxxxxxxxxxxx4'
    wechat_agent_id = 999999
    wechat_app_secret = 'rOobbhSiRxxxxxxxxxxxxxxxxxcRMxT4MQDxM'
    wechat_user_ids = 'ZhangSan|LiSi'

    msgType = 'markdown'

    
    try:
        data = json.loads(sys.argv[1].replace('\n', ''))
    except Exception as e:
        raise Exception('数据载入失败: {}'.format(e))
    
    msg = {
        "id": data['id'],
        "title": data['title'],
        "env": data['form_data'][0].get('ZQY_DEPLOY_ENV'),
        "applicant": data['form_data'][0].get('ZQY_APPLYER'),
        "reason": data['form_data'][0].get('ZQY_APPLY_REASON'),
        "date": data['form_data'][0].get('ZQY_DATE')
    }

    wechat = WeChatAlerter(wechat_corp_id, wechat_app_secret, wechat_agent_id, wechat_user_ids)

    db = MySqlite3(DB_PATH)
    db_result = db.fetch_one()
    if not list(db_result):
        access_token, timestamp = wechat.get_token()
        db.insert_one(access_token, timestamp)
        wechat.send_msg(msg, msgType)
    else:
        db_result = db.fetch_one()
        for row in db_result:
            access_token = row[0]
            timestamp = row[1]
        if verify_token(timestamp):
            # wechat.set_access_token(access_token)
            wechat.send_msg(msg, msgType, access_token)
        else:
            access_token, timestamp = wechat.get_token()
            db.update_one(access_token, timestamp)
            wechat.send_msg(msg, msgType, access_token)
    
    db.close()

    
    
    
