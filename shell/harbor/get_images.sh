#!/bin/bash

# Harbor 配置
HARBOR_USER="admin"
HARBOR_PASSWORD="nt5xxxxxxxxxxxxx/vBb"
HARBOR_URL="https://harbor.xxxn.cn"  # 支持 http:// 或 https://
PROJECT="hxxxxn"

# 自动识别协议并提取域名
if [[ "$HARBOR_URL" == http://* ]]; then
    HARBOR_PROTOCOL="http"
    HARBOR_DOMAIN="${HARBOR_URL#http://}"
elif [[ "$HARBOR_URL" == https://* ]]; then
    HARBOR_PROTOCOL="https"
    HARBOR_DOMAIN="${HARBOR_URL#https://}"
else
    HARBOR_PROTOCOL="https"
    HARBOR_DOMAIN="$HARBOR_URL"
    HARBOR_URL="$HARBOR_PROTOCOL://$HARBOR_DOMAIN"
fi

# curl 参数（添加 -s 静默模式）
CURL_OPTS="-s -k -u $HARBOR_USER:$HARBOR_PASSWORD"

# 登录 Harbor
docker login "$HARBOR_DOMAIN" -u "$HARBOR_USER" -p "$HARBOR_PASSWORD" > /dev/null 2>&1

# 获取项目下所有镜像仓库（curl 静默执行）
IMAGE_NAMES=$(curl $CURL_OPTS -H "Content-Type: application/json" -X GET "$HARBOR_URL/api/v2.0/projects/$PROJECT/repositories?page_size=100" | jq -r '.[].name')

# 遍历镜像仓库
for IMAGE in $IMAGE_NAMES; do
    echo "处理镜像仓库: $IMAGE"

    # 获取所有 tags（curl 静默执行）
    TAGS=$(curl $CURL_OPTS -H "Content-Type: application/json" -X GET "$HARBOR_URL/v2/$IMAGE/tags/list" | jq -r '.tags[]' 2>/dev/null)

    if [ -z "$TAGS" ]; then
        echo "⚠️ 无 tag，跳过 $IMAGE"
        continue
    fi

    # 直接排序取最大值
    LATEST_TAG=$(echo $TAGS | tr ' ' '\n' | sort -n | tail -n1)

    echo "最新 tag: $LATEST_TAG"

    # 构造镜像地址
    FULL_IMAGE="$HARBOR_DOMAIN/$IMAGE:$LATEST_TAG"
    LOCAL_IMAGE_NAME="${IMAGE##*/}-$LATEST_TAG.tar"

    echo "拉取镜像: $FULL_IMAGE"
    docker pull "$FULL_IMAGE" > /dev/null 2>&1

    echo "导出镜像: $LOCAL_IMAGE_NAME"
    docker save -o "$LOCAL_IMAGE_NAME" "$FULL_IMAGE" > /dev/null 2>&1

    echo "镜像导出完成: $LOCAL_IMAGE_NAME"
done

echo "所有镜像处理完成"
