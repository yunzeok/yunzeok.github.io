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

# 检查是否已安装 tar
if ! command -v tar &> /dev/null; then
    echo "未找到 tar，将尝试根据系统类型安装..."

    # 检测系统类型，并根据不同类型进行安装
    if [ -f /etc/debian_version ]; then
        echo "正在安装 tar（适用于Debian/Ubuntu系统）..."
        sudo apt update
        sudo apt install -y tar
    elif [ -f /etc/redhat-release ]; then
        echo "正在安装 tar（适用于Red Hat/CentOS系统）..."
        sudo yum install -y tar
    else
        echo "无法确定系统类型或不支持当前系统。请手动安装 tar。"
        exit 1
    fi
fi

echo "如已经安装过，请提前做好配置文件的备份"
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
    echo "2. 自动从网络下载"
    echo "3. 下载特定版本 v0.50.0"
    read -p "输入数字 (1/2/3): " download_choice

    case $download_choice in
        1)
            echo "请手动下载 frp.tar.gz 并放置在 $FRP_PACKAGE_PATH"
            echo "请自行前往 https://github.com/fatedier/frp/releases/ 中下载 Linux 版本文件，将其改名为 frp.tar.gz 并存放在用户文件夹 $HOME 下"
            echo "请下载对应的版本，否则可能无法正常使用"
            exit 1
            ;;
        2)
            echo "正在从网络下载..."
            echo "本脚本所提供的网络安装（定时自动拉取最新版），安装版本可能落后于 GitHub 版本"
            curl -o "$FRP_PACKAGE_PATH" "https://yunzeo.github.io/download/frp.tar.gz"
            ;;
        3)
            echo "正在下载特定版本 v0.50.0..."
            curl -o "$FRP_PACKAGE_PATH" "https://yunzeo.github.io/download/old/frp.tar.gz"
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

# 检查 tar 解压是否成功
if [ -f "$INSTALL_DIR/$COMPONENT" ] && [ -f "$CONFIG_DIR/${COMPONENT}.ini" ]; then
    echo "文件成功解压并移动到安装目录。"

    # 检查是否成功解压出frps和frpc文件
    if [ -f "$INSTALL_DIR/frps" ] && [ -f "$INSTALL_DIR/frpc" ]; then
        echo "成功解压出 $COMPONENT 。"
    else
        echo "解压过程中出现问题，$COMPONENT 文件未成功解压。请检查并重新运行脚本。"
        exit 1
    fi
else
    echo "解压过程中出现问题，文件未成功解压。请检查并重新运行脚本。"
    exit 1
fi

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
echo "开机自启服务：sudo systemctl enable ${COMPONENT}.service"
echo "停止自启服务：sudo systemctl disable ${COMPONENT}.service"
echo "查看服务状态：sudo systemctl status ${COMPONENT}.service"
