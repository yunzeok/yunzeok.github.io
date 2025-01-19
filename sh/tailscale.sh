#!/bin/bash

# 检测是否安装了 Docker
if ! command -v docker &> /dev/null; then
    echo "未检测到 Docker，正在安装 Docker..."
    curl -sSL https://get.docker.com/ | sh
    sudo systemctl start docker && sudo systemctl enable docker.service
    echo "Docker 安装完成。"
fi

# 检测是否使用 docker compose 还是 docker-compose
DOCKER_COMPOSE_CMD=""
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "未检测到 docker compose 或 docker-compose，请先安装后再运行此脚本。"
    exit 1
fi

# 创建 Tailscale 文件夹
mkdir -p /root/tailscale

# 提示用户输入 TS_HOSTNAME 和 TS_AUTHKEY
read -p "请输入 Tailscale 主机名 (TS_HOSTNAME): " TS_HOSTNAME
read -p "请输入 Tailscale 授权密钥 (TS_AUTHKEY): " TS_AUTHKEY

# 定义脚本中的 docker-compose.yml 内容
SCRIPT_DOCKER_COMPOSE="""version: '3.8'

services:
  tailscale:
    container_name: tailscale
    restart: always
    network_mode: host
    volumes:
      - /var/lib:/var/lib
      - /dev/net/tun:/dev/net/tun
      - /var/run/tailscale:/var/run/tailscale
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - TS_ACCEPT_DNS=false
      - TS_AUTH_ONCE=false
      - TS_AUTHKEY=$TS_AUTHKEY
      - TS_DEST_IP=
      - TS_KUBE_SECRET=tailscale
      - TS_HOSTNAME=$TS_HOSTNAME
      - TS_OUTBOUND_HTTP_PROXY_LISTEN=
      - TS_ROUTES=192.168.3.0/24
      - TS_SOCKET=/var/run/tailscale/tailscaled.sock
      - TS_SOCKS5_SERVER=
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_USERSPACE=true
      - TS_EXTRA_ARGS=
    image: tailscale/tailscale:latest"""

# 检查是否已有 docker-compose.yml 文件
EXISTING_COMPOSE_FILE="/root/tailscale/docker-compose.yml"
if [ -f "$EXISTING_COMPOSE_FILE" ]; then
    echo "检测到现有的 docker-compose.yml 文件，正在检查更新..."

    # 读取旧配置中的 TS_HOSTNAME、TS_AUTHKEY 和 TS_ROUTES
    OLD_TS_HOSTNAME=$(grep -oP '(?<=TS_HOSTNAME=).*' "$EXISTING_COMPOSE_FILE")
    OLD_TS_AUTHKEY=$(grep -oP '(?<=TS_AUTHKEY=).*' "$EXISTING_COMPOSE_FILE")
    OLD_TS_ROUTES=$(grep -oP '(?<=TS_ROUTES=).*' "$EXISTING_COMPOSE_FILE")

    # 使用旧配置覆盖新配置的对应值
    if [ -n "$OLD_TS_HOSTNAME" ]; then
        TS_HOSTNAME="$OLD_TS_HOSTNAME"
    fi
    if [ -n "$OLD_TS_AUTHKEY" ]; then
        TS_AUTHKEY="$OLD_TS_AUTHKEY"
    fi
    if [ -n "$OLD_TS_ROUTES" ]; then
        SCRIPT_DOCKER_COMPOSE=$(echo "$SCRIPT_DOCKER_COMPOSE" | sed "s|TS_ROUTES=.*|TS_ROUTES=$OLD_TS_ROUTES|")
    fi

    # 更新配置文件
    echo "$SCRIPT_DOCKER_COMPOSE" > "$EXISTING_COMPOSE_FILE"
    echo "更新完成，现有配置已更新。"
else
    echo "$SCRIPT_DOCKER_COMPOSE" > "$EXISTING_COMPOSE_FILE"
    echo "已生成新的 docker-compose.yml 文件。"
fi

# 启动 Docker 服务
$DOCKER_COMPOSE_CMD -f /root/tailscale/docker-compose.yml up -d
