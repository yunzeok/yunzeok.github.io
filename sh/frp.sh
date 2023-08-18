#!/bin/bash

# 检查是否已安装 curl
if ! command -v curl &> /dev/null; then
    echo "未找到 curl，将尝试根据系统类型安装..."
    
    # 检测系统类型，并根据不同类型进行安装
    if [ -f /etc/debian_version ]; then
        echo "正在安装 curl（适用于Debian/Ubuntu系统）..."
        sudo apt update
        sudo apt install -y curl
    elif [ -f /etc/redhat-release ]; then
        echo "正在安装 curl（适用于Red Hat/CentOS系统）..."
        sudo yum install -y curl
    else
        echo "无法确定系统类型或不支持当前系统。请手动安装 curl。"
        exit 1
    fi
fi

# 检查是否已安装systemd
if ! command -v systemctl &> /dev/null; then
    echo "系统未安装systemd，将尝试根据系统类型安装..."
    
    # 检测系统类型，并根据不同类型进行安装
    if [ -f /etc/debian_version ]; then
        echo "正在安装systemd（适用于Debian/Ubuntu系统）..."
        sudo apt update
        sudo apt install -y systemd
    elif [ -f /etc/redhat-release ]; then
        echo "正在安装systemd（适用于Red Hat/CentOS系统）..."
        sudo yum install -y systemd
    else
        echo "无法确定系统类型或不支持当前系统。请手动安装systemd。"
        exit 1
    fi
fi
echo "本脚本推荐本地安装，请自行前往https://github.com/fatedier/frp/releases/中下载linux版本文件，将其改名为frp.tar.gz并存放在用户文件夹 $HOME 下"
echo "本脚本提供网络安装，但是安装的版本为v0.51.3"
# 获取用户选择是安装frpc还是frps
echo "请选择要安装的组件："
echo "1. frpc"
echo "2. frps"
read -p "输入数字 (1/2): " choice

case $choice in
    1)
        COMPONENT="frpc"
        ;;
    2)
        COMPONENT="frps"
        ;;
    *)
        echo "无效的选择"
        exit 1
        ;;
esac

# 定义frp.tar.gz的路径和解压目录
FRP_PACKAGE_PATH="$HOME/frp.tar.gz"
INSTALL_DIR="/usr/local/bin/$COMPONENT"
CONFIG_DIR="/etc/$COMPONENT"

# 检查frp.tar.gz是否存在
if [ ! -f "$FRP_PACKAGE_PATH" ]; then
    echo "frp.tar.gz 不存在，请选择操作："
    echo "1. 手动下载并放置 frp.tar.gz"
    echo "2. 自动从 https://hub.yunzeofficial.cn/download/frp.tar.gz 下载"
    read -p "输入数字 (1/2): " download_choice

    case $download_choice in
        1)
            echo "请手动下载 frp.tar.gz 并放置在 $FRP_PACKAGE_PATH"
            exit 1
            ;;
        2)
            echo "正在从 https://hub.yunzeofficial.cn/download/frp.tar.gz 下载..."
            curl -o "$FRP_PACKAGE_PATH" "https://hub.yunzeofficial.cn/download/frp.tar.gz"
            ;;
        *)
            echo "无效的选择"
            exit 1
            ;;
    esac
fi

# 创建安装目录和配置目录
sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$CONFIG_DIR"

# 解压frp.tar.gz并移动其中的文件到安装目录
tar -xzvf "$FRP_PACKAGE_PATH" --strip-components=1 -C "$INSTALL_DIR"

# 创建示例配置文件
sudo touch "$CONFIG_DIR/${COMPONENT}.ini"
# 这里可以根据需要添加默认配置内容

# 创建systemd服务单元文件
sudo tee "/etc/systemd/system/${COMPONENT}.service" > /dev/null <<EOL
[Unit]
Description=frp $COMPONENT
After=network.target

[Service]
Type=simple
ExecStart="$INSTALL_DIR/$COMPONENT" -c "$CONFIG_DIR/${COMPONENT}.ini"
Restart=on-failure

[Install]
WantedBy=default.target
EOL

# 启用并启动frp服务
sudo systemctl enable "${COMPONENT}.service"
sudo systemctl start "${COMPONENT}.service"

# 输出安装完成信息和管理服务的命令
echo "$COMPONENT 安装完成！安装目录：$INSTALL_DIR"
echo "配置文件目录：$CONFIG_DIR"
echo "已设置开机自启"
echo "$COMPONENT 服务已启动，可以使用以下命令管理："
echo "启动服务：sudo systemctl start ${COMPONENT}.service"
echo "停止服务：sudo systemctl stop ${COMPONENT}.service"
echo "重启服务：sudo systemctl restart ${COMPONENT}.service"
echo "查看服务状态：sudo systemctl status ${COMPONENT}.service"
