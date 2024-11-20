#!/bin/bash

# 创建 Tailscale 文件夹
mkdir -p /root/tailscale

# 提示用户输入 TS_HOSTNAME 和 TS_AUTHKEY
read -p "请输入 Tailscale 主机名 (TS_HOSTNAME): " TS_HOSTNAME
read -p "请输入 Tailscale 授权密钥 (TS_AUTHKEY): " TS_AUTHKEY

# 创建 docker-compose.yml 文件
cat <<EOF > /root/tailscale/docker-compose.yml
version: '3.8'

services:
  tailscale:
    container_name: tailscale
    restart: always
    network_mode: host
    volumes:
      - /var/lib:/var/lib
      - /dev/net/tun:/dev/net/tun
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
    image: tailscale/tailscale:latest
EOF

# 启动 Docker 服务
docker compose -f /root/tailscale/docker compose.yml up -d
