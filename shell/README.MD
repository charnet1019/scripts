# 使用shc加密shell脚本  
> shc -r -f analyze_big_keys.sh -o analyze_big_keys  

[shc仓库](https://github.com/neurobin/shc)


# es备份
elasticdump --concurrency=4 --limit=2000 --input=http://10.0.0.49:9200/order --output=order.json --type=data
# es还原
elasticdump --output=http://127.0.0.1:9200/order --type=data --input=order.json
