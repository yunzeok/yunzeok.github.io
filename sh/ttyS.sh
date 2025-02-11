#!/bin/bash

set -e

# 检查并安装 sudo 和 systemctl（如果未安装）
if ! command -v sudo &> /dev/null; then
    apt update && apt install -y sudo
fi

if ! command -v systemctl &> /dev/null; then
    apt update && apt install -y systemd
fi

SERVICE_PATH="/lib/systemd/system/ttyS0.service"

# 创建 systemd 服务文件
echo "[Unit]
Description=Serial Console Service

[Service]
ExecStart=/sbin/getty -L 115200 ttyS0 xterm
Restart=always

[Install]
WantedBy=multi-user.target" | sudo tee $SERVICE_PATH > /dev/null

# 重新加载 systemd
sudo systemctl daemon-reload

# 启用并启动 ttyS0 服务
sudo systemctl enable ttyS0
sudo systemctl start ttyS0

# 输出状态
sudo systemctl status ttyS0 --no-pager
