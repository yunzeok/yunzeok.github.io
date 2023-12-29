#!/bin/bash

# Check if sudo is installed 检查sudo是否安装
if ! command -v sudo &> /dev/null; then
    echo "sudo is not installed, attempting to install... sudo未安装，尝试安装..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y sudo
    elif command -v yum &> /dev/null; then
        sudo yum install -y sudo
    else
        echo "Unsupported package manager. Unable to install sudo. Please manually install sudo before running the script."
        echo "不支持的包管理器，无法安装sudo。请在运行脚本之前手动安装sudo。"
        exit 1
    fi
fi

# Check system type 检查系统类型
if command -v apt-get &> /dev/null; then
    PACKAGE_MANAGER="apt-get"
elif command -v yum &> /dev/null; then
    PACKAGE_MANAGER="yum"
else
    echo "Unsupported package manager 不支持的包管理器"
    exit 1
fi

echo "Detected package manager 检测到的包管理器: $PACKAGE_MANAGER"

# Install curl 安装curl
if command -v curl &> /dev/null; then
    echo "curl is already installed curl已安装"
else
    echo "Installing curl... 安装 curl..."
    if [ "$PACKAGE_MANAGER" == "apt-get" ]; then
        sudo $PACKAGE_MANAGER update
        sudo $PACKAGE_MANAGER install -y curl
    elif [ "$PACKAGE_MANAGER" == "yum" ]; then
        sudo $PACKAGE_MANAGER install -y curl
    fi
fi

# Ask the user to choose the script to run 询问用户选择要运行的脚本
echo "Please choose the script to run 请选择要运行的脚本:"
echo "1. frp "
echo "2. chatgpt "
echo "3. debian12 "

read -p "Enter the script number to run 输入要运行的脚本编号 (1/2/3): " script_choice

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
        echo "Invalid choice 选择无效"
        ;;
esac
