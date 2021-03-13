#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import requests
import setproctitle
import time
import sys
import logging

from urllib import urlencode

reload(sys)
sys.setdefaultencoding('utf8')

mq_host="10.106.x.x"
mq_port=15672
mq_user="monitor"
mq_pass="xxxx"
queue_url="http://%s:%d/api/queues" % (mq_host, mq_port)


# 获取rabbitmq的所有队列信息
def get_queue_info(user, password, url):
    try:
        respones=requests.get(url=url, auth=(user, password))
        #print respones.status_code
        data=json.loads(respones.content.decode())
        return data
    except Exception as e:
        print(e)

# 发送告警信息
def send_msg(data, robot_webhook_url):
    #logging.info('进入send_msg')
    #queue_names = []
    queue_ready = {}

    try:
        for i in data:
            queue_ready[i['name']] = i['messages_ready']


        for name in queue_ready.keys():
            if queue_ready[name] > 1000000:
                #print("queue name is: {}, lag num is: {}".format(name, queue_ready[name]))
                str_msg = '生产环境' + "项目队列: " + name + '消息积压超过100万,当前值为: ' + str(queue_ready[name]) + ', 请及时检查.'
                values = {
                    "msgtype": 'text',
                    "text": {'content': str_msg},
                }
                msg = json.dumps(values)
                headers={'Content-Type':'application/json'}
                resp = requests.post(url=robot_webhook_url, data=msg, headers=headers)
                logging.info(resp)
                logging.info(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + ' 队列超过100万调用')
    except Exception as e:
        print(e)
    #return 'ok'
    


def main():
    #logging.info('进入main函数')
    setproctitle.setproctitle('monitormq')
    robot_webhook = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=a4f6c018-e2f7-xxxxxxxxxxxxxxxxxxxxx'
    data = get_queue_info(mq_user, mq_pass, queue_url)
    #print(data)
    send_msg(data, robot_webhook)


if __name__ == '__main__':
    LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"
    DATE_FORMAT = "%m/%d/%Y %H:%M:%S %p"
    logging.basicConfig(filename='/opt/monitor/monitor.log', level=logging.DEBUG, format=LOG_FORMAT, datefmt=DATE_FORMAT)

    #pid = os.fork()
    #if pid != 0:
    #    logging.info('退出父进程')
    #    sys.exit(0)
    #else:
    #    #main()
    #    logging.info('进入主程序')
    #time.sleep(300)

    while True:
        main()
        time.sleep(300)






