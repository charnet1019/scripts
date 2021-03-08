#!/bin/bash

PUBLISH_TIME=$(date "+%Y-%m-%d %T")
PROJECT_NAME="iot"
#PROJECT_SUBMODULE="bar-patrol"
PROJECT_SUBMODULE="${1}"

#curl -X POST \
#  https://open.feishu.cn/open-apis/bot/v2/hook/49c2a27b-eeea-425f-xxxxx \
#  -H 'Content-Type: application/json' \
#  -d '{
#    "msg_type": "text",
#    "content": {
#        "text": "'"物联网项目${PROJECT_SUBMODULE}模块已上线,请稍后验证."'"
#    }
#}'


curl -X POST \
  https://open.feishu.cn/open-apis/bot/v2/hook/49c2a27b-eeea-xxxxxxxxxxxxx \
  -H 'Content-Type: application/json' \
  -d "{
    \"msg_type\": \"text\",
    \"content\": {
        \"text\": \"${PROJECT_SUBMODULE} 已于 ${PUBLISH_TIME} 发布，请稍后验证改动内容。\"
    }
}"


