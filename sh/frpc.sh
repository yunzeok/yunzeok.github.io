#!/bin/env bash

set -e  # 在发生错误时立即退出脚本

# 定义变量
FRP_DOWNLOAD_URL=$(curl -sL "https://github.com/fatedier/frp/releases/latest" | grep -o -E "https://github.com/fatedier/frp/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/frp_[0-9]+\.[0-9]+\.[0-9]+_linux_amd64\.tar\.gz")
TMP_DIR=$(mktemp -d)

# 错误处理函数
handle_error() {
    echo "安装过程中发生错误，请检查并修复问题。"
    cleanup
    exit 1
}

# 清理临时文件函数
cleanup() {
    echo "清理临时文件..."
    cd ~
    rm -rf "$TMP_DIR"
}

trap handle_error ERR  # 注册错误处理函数

# 检查是否已安装 frpc
if command -v frpc &>/dev/null; then
    INSTALLED_VERSION=$(frpc -v | awk '{print $3}')
    LATEST_VERSION=$(curl -sL "https://github.com/fatedier/frp/releases/latest" | grep -o -E "v[0-9]+\.[0-9]+\.[0-9]+" | cut -c 2-)
    
    if [[ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]]; then
        echo "frpc 已安装且为最新版，无需更新。"
        exit 0
    else
        echo "已安装 frpc 版本：$INSTALLED_VERSION"
        echo "最新 frpc 版本：$LATEST_VERSION"
        echo "更新 frpc..."
    fi
fi

# 创建临时目录并进入
echo "创建临时目录并下载 frp..."
cd "$TMP_DIR"
wget "$FRP_DOWNLOAD_URL"
tar -zxvf "frp_*.tar.gz"

# 提取文件名中的版本号
FRP_VERSION=$(tar -tf "frp_*.tar.gz" | grep -o -E "[0-9]+\.[0-9]+\.[0-9]+")

# 检查是否已有配置文件，如果没有则创建目录
if [ ! -d "/etc/frp/" ]; then
    echo "创建 frp 配置文件目录..."
    sudo mkdir -p "/etc/frp/"
fi

# 保存旧的配置文件
if [ -f "/etc/frp/frpc.ini" ]; then
    echo "保存旧的 frpc 配置文件..."
    sudo mv "/etc/frp/frpc.ini" "/etc/frp/frpc.ini.old"
fi

# 复制二进制文件到系统路径
echo "安装 frp..."
sudo cp "frp_${FRP_VERSION}_linux_amd64/frpc" "/usr/local/bin/"

# 如果存在旧的配置文件，则恢复
if [ -f "/etc/frp/frpc.ini.old" ]; then
    echo "恢复旧的 frpc 配置文件..."
    sudo mv "/etc/frp/frpc.ini.old" "/etc/frp/frpc.ini"
fi

# 创建 systemd 服务单元
echo "创建 systemd 服务单元..."
sudo tee /etc/systemd/system/frpc.service > /dev/null << EOF
[Unit]
Description=frp client service
After=network.target

[Service]
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.ini
Restart=always
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 启用 frpc 服务开机自启
echo "启用 frpc 服务开机自启..."
sudo systemctl enable frpc

# 启用并启动 frpc 服务
echo "启用并启动 frpc 服务..."
sudo systemctl start frpc

# 创建管理 frp 服务的提示信息
echo "frpc 服务已添加到 systemd。"
echo "可以使用以下命令来管理 frpc 服务："
echo "# 启动 frp"
echo "sudo systemctl start frpc"
echo "# 停止 frp"
echo "sudo systemctl stop frpc"
echo "# 重启 frp"
echo "sudo systemctl restart frpc"
echo "# 查看 frp 状态"
echo "sudo systemctl status frpc"

# 清理临时文件
cleanup

echo "安装完成！"
echo "frpc 二进制文件已安装到 /usr/local/bin/"
echo "frpc 配置文件应放置在 /etc/frp/ 目录中"
