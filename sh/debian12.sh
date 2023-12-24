#!/bin/bash

# 安装Vim编辑器（如果未安装）
sudo apt-get update
sudo apt-get install -y vim

# 备份原始配置文件
sudo cp /etc/network/interfaces /etc/network/interfaces.bak

# 获取网络接口名称
network_interface=$(grep -Po 'iface \K[^ ]+' /etc/network/interfaces)

# 将dhcp改为static并追加用户提供的静态IP和网关
read -p "请输入静态IP地址: " static_ip
read -p "请输入网关地址: " gateway

# 使用 sed 命令替换网络配置文件中的 dhcp 为 static，并追加静态IP和网关
sudo sed -i '/iface '$network_interface' inet dhcp/,/^$/ {
  s/iface '$network_interface' inet dhcp/iface '$network_interface' inet static\n    address '"$static_ip"'\n    gateway '"$gateway"'/;
  }' /etc/network/interfaces

# 修改apt源为阿里云源（适用于 Debian 12 Bookworm 版本）
cp /etc/apt/sources.list /etc/apt/sources.list.bak
cat <<EOL | sudo tee /etc/apt/sources.list > /dev/null
deb https://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware contrib
deb-src https://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware contrib
deb https://mirrors.aliyun.com/debian-security/ bookworm-security main
deb-src https://mirrors.aliyun.com/debian-security/ bookworm-security main
deb https://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware contrib
deb-src https://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware contrib
deb https://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware contrib
deb-src https://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware contrib
EOL

# 更新软件包列表
sudo apt-get update

# 重启网络服务
sudo systemctl restart networking

echo "静态IP配置和apt源修改完成。"
