#!/bin/bash

set -e

echo "请选择安装方式："
echo "1) 国内（Aliyun 镜像，默认）"
echo "2) 国外（官方源）"
read -p "请输入选项 (1 或 2，默认 1): " choice

if [ -z "$choice" ] || [ "$choice" == "1" ]; then
    echo "使用 Aliyun 镜像安装 Docker..."
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

    echo "配置国内镜像源..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.1panel.live",
    "https://dockerproxy.1panel.live",
    "https://docker.1panelproxy.com",
    "https://proxy.1panel.live",
    "https://docker.1ms.run",
    "https://hub1.nat.tf",
    "https://docker.ketches.cn",
    "https://docker.m.daocloud.io"
  ]
}
EOF
elif [ "$choice" == "2" ]; then
    echo "使用官方源安装 Docker..."
    curl -sSL https://get.docker.com/ | sh
else
    echo "无效选项，退出安装。"
    exit 1
fi

echo "启动并设置 Docker 开机自启..."
sudo systemctl start docker
sudo systemctl enable docker.service

if [ "$choice" == "1" ]; then
    echo "重启 Docker 以应用国内镜像源..."
    sudo systemctl restart docker
fi

echo "Docker 安装完成，检查版本："
docker --version
