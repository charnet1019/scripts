#!/bin/bash

# 调用飞书接口无签名验证

PUBLISH_TIME=$(date "+%Y-%m-%d %T")
PROJECT_NAME="myproject"
PROJECT_SUBMODULE="${1}"


curl -X POST \
  https://open.feishu.cn/open-apis/bot/v2/hook/49c2a27b-eeea-425f-a818-1cf463f4ebb2 \
  -H 'Content-Type: application/json' \
  -d "{
    \"msg_type\": \"text\",
    \"content\": {
        \"text\": \"${PROJECT_SUBMODULE} 已于 ${PUBLISH_TIME} 发布，请稍后验证改动内容。\"
    }
}"
