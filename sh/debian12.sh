#!/bin/bash

set -e

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户运行此脚本"
  exit 1
fi

# 检测是否为 Debian 12
OS_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d '"' -f 2)
if [ "$OS_VERSION" != "12" ]; then
  echo "此脚本仅适用于 Debian 12，当前系统版本: $OS_VERSION"
  exit 1
fi

# 安装必要工具
echo "安装必要工具：vim sudo unzip curl..."
apt update -y
apt install -y vim sudo unzip curl

echo "所有工具安装完成"

if ! command -v sudo &> /dev/null; then
    apt install -y sudo
fi

if ! command -v systemctl &> /dev/null; then
    apt install -y systemd
fi

# 更换 Debian 12 镜像源
echo "更换 Debian 12 镜像源..."
cat > /etc/apt/sources.list <<EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
apt update -y

echo "Debian 12 镜像源已更新"

# 开启 root 远程 SSH 登录
echo "开启 root 远程 SSH 登录..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

echo "SSH 配置已更新并重启"

# 选择是否安装 Docker（20s 超时自动选择默认 1）
echo "是否安装 Docker？"
echo "1) 安装 Docker（默认）"
echo "2) 跳过安装"
read -t 20 -p "请输入选项 (1 或 2，默认 1): " install_docker || install_docker=1

if [ -z "$install_docker" ] || [ "$install_docker" == "1" ]; then
    echo "请选择 Docker 安装方式（20s 超时自动选择默认 1）："
    echo "1) 国内（Aliyun 镜像，默认）"
    echo "2) 国外（官方源）"
    read -t 20 -p "请输入选项 (1 或 2，默认 1): " choice || choice=1

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
    systemctl start docker
    systemctl enable docker.service

    if [ "$choice" == "1" ]; then
        echo "重启 Docker 以应用国内镜像源..."
        systemctl restart docker
    fi

    echo "Docker 安装完成，检查版本："
    docker --version
else
    echo "跳过 Docker 安装"
fi

SERVICE_PATH="/lib/systemd/system/ttyS0.service"

echo "创建 ttyS0 串口服务..."
echo "[Unit]
Description=Serial Console Service

[Service]
ExecStart=/sbin/getty -L 115200 ttyS0 xterm
Restart=always

[Install]
WantedBy=multi-user.target" | sudo tee $SERVICE_PATH > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable ttyS0
sudo systemctl start ttyS0


# 提示用户如何删除安装时创建的账户
echo "如果需要删除新系统安装时创建的用户，请手动运行以下命令："
echo "注意，必须要用root登录，且不是使用登录用户使用su切换的root"
echo "sudo userdel -r 用户名"
echo "请确保不要删除 root 用户，以免影响系统运行。"
