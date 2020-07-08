# -*- coding: UTF-8 -*-

from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk

import io
import sys
import os
import json


if sys.getdefaultencoding() != 'utf-8':
    reload(sys)
    sys.setdefaultencoding('utf-8')


class ElasticObj:
    def __init__(self, index_name, index_type, ip):
        """
        :param index_name: 索引名称
        :param index_type: 索引类型
        """
        self.index_name = index_name
        self.index_type = index_type
        # 无用户名密码状态
        self.es = Elasticsearch([ip])
        # 用户名密码状态
        # self.es = Elasticsearch([ip],http_auth=('elastic', 'password'),port=9200)

    def create_index(self):
        '''
        创建索引,创建索引名称为ott，类型为ott_type的索引
        :param ex: Elasticsearch对象
        :return:
        '''
        # 创建映射
        _index_mappings = {
            "mappings": {
                self.index_type: {
                    "properties": {
                        "host": {
                            'type': 'string'
                        },
                        "port": {
                            'type': 'short'
                        },
                        "datetime": {
                            'type': 'long'
                        },
                        "service": {
                            'type': 'string'
                        },
                        "banner": {
                            'type': 'text'
                        },
                        "tcpudp": {
                            'type': 'string'
                        },
                        "country": {
                            'type': 'string'
                        }
                    }
                }

            },
            "include_type_name": "true"
        }
        if self.es.indices.exists(index=self.index_name) is not True:
            res = self.es.indices.create(index=self.index_name, body=_index_mappings, ignore=400)
            #print(res)
	
    def insert_data(self, inputfile, country):
        f = open(inputfile, 'r', encoding='UTF-8')
        data = []
        for line in f.readlines():
            # print(line.strip())
           
            # print(json.loads(line))
            jline=json.loads(line)
            jline['country'] = country
 
            print(jline)

            # save list
            data.append(json.dumps(jline))
        f.close()

        #print(data)

        ACTIONS = []
        i = 1
        bulk_num = 5000
        for list_line in data:
            # 去掉引号
            list_line = eval(list_line)
            # print(list_line)
            action = {
                "_index": self.index_name,
                "_type": self.index_type,
                #"_id": i,  # _id 也可以默认生成，不赋值
                "_source": {
                    "host": list_line["host"],
                    "port": list_line["port"],
                    "datetime": list_line["datetime"],
                    "service": list_line["service"],
                    "banner": list_line["banner"],
                    "tcpudp": list_line["tcpudp"],
                    "country": list_line["country"]}
            }
            i += 1
            ACTIONS.append(action)
            # 批量处理
            if len(ACTIONS) == bulk_num:
                #print('插入', i // bulk_num, '批数据')
                #print(len(ACTIONS))
                success, _ = bulk(self.es, ACTIONS, index=self.index_name, raise_on_error=True)
                del ACTIONS[0:len(ACTIONS)]
                #print(success)

        if len(ACTIONS) > 0:
            success, _ = bulk(self.es, ACTIONS, index=self.index_name, raise_on_error=True)
            del ACTIONS[0:len(ACTIONS)]
            #print('Performed %d actions' % success)


if __name__ == '__main__':
    #rootdir = '/data/scanner'
    rootdir = '/data/result'
    es_ip = '10.10.40.246'
    fixed_index_name = 'scanports'
    list = os.listdir(rootdir)

    obj = ElasticObj(fixed_index_name, "_doc", ip=es_ip)
    obj.create_index()

    for i in range(0, len(list)):
        path = os.path.join(rootdir, list[i])
        if os.path.isfile(path):
            filename =list[i].lower().split('.')
            country=filename[0].split('-')[0]
            #print(filename[0])
            #print(country)
            #obj = ElasticObj(filename[0], "_doc", ip=es_ip)
            #obj.create_index()
            print("begin handler file {}".format(path))
            obj.insert_data(path, country)
    #obj = ElasticObj("my-telnet-23", "_doc", ip="10.10.40.246")
    #obj.create_index()
    #obj.insert_data("./result/MY-telnet-23.txt")
    
    
    
