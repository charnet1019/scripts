#!/usr/bin/env bash
# 删除指定日期前的数据

HOST=localhost:9200
INDEX=my_index
START_DATE=2022-01-01
END_DATE=2022-03-31

curl -XPOST '${HOST}/${INDEX}/_delete_by_query' -H 'Content-Type: application/json' -d '{
  "query": {
    "range": {
      "created_at": {
        "lt": "'${START_DATE}'"
      }
    }
  }
}'




HOST=localhost:9200
INDEX=my_index
START_DATE=now-200d   # 删除200天前的数据
curl -XPOST "${HOST}/${INDEX}/_delete_by_query" -H 'Content-Type: application/json' -d '{
  "query": {
    "range": {
      "@timestamp": {
        "lt": "'${START_DATE}'",
        "format": "epoch_millis"
      }
    }
  }
}'
