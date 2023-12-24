#!/bin/bash

# 检查sudo是否安装
if ! command -v sudo &> /dev/null; then
    echo "sudo 未安装，尝试安装..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y sudo
    elif command -v yum &> /dev/null; then
        sudo yum install -y sudo
    else
        echo "不支持的包管理器，无法安装sudo。请手动安装sudo后再运行脚本。"
        exit 1
    fi
fi

# 检查系统类型
if command -v apt-get &> /dev/null; then
    PACKAGE_MANAGER="apt-get"
elif command -v yum &> /dev/null; then
    PACKAGE_MANAGER="yum"
else
    echo "不支持的包管理器"
    exit 1
fi

echo "Detected package manager: $PACKAGE_MANAGER"

# 安装curl
if command -v curl &> /dev/null; then
    echo "curl 已安装"
else
    echo "安装 curl..."
    if [ "$PACKAGE_MANAGER" == "apt-get" ]; then
        sudo $PACKAGE_MANAGER update
        sudo $PACKAGE_MANAGER install -y curl
    elif [ "$PACKAGE_MANAGER" == "yum" ]; then
        sudo $PACKAGE_MANAGER install -y curl
    fi
fi

# 询问用户选择要运行的脚本
echo "请选择要运行的脚本:"
echo "1. frp "
echo "2. chatgpt "
echo "3. debian12 "

read -p "请输入选择的脚本编号（1/2/3）: " script_choice

case $script_choice in
    1)
        bash <(curl -Ls https://yunzeo.github.io/sh/frp.sh)
        ;;
    2)
        bash <(curl -Ls https://yunzeo.github.io/sh/chatgpt.sh)
        ;;
    3)
        bash <(curl -Ls https://yunzeo.github.io/sh/debian12.sh)
        ;;
    *)
        echo "无效的选择"
        ;;
esac
