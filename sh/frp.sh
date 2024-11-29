#!/bin/bash

# 输出带颜色的提示信息
info() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }
exit_with_message() {
    local message=$1
    local code=${2:-1}
    echo -e "\033[1;31m$message\033[0m"
    exit $code
}

# 检查依赖并安装
install_dependency() {
    local package=$1
    if ! command -v $package &> /dev/null; then
        info "未找到 $package，将尝试安装..."
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y $package || exit_with_message "$package 安装失败！"
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y $package || exit_with_message "$package 安装失败！"
        else
            exit_with_message "无法确定系统类型，请手动安装 $package。"
        fi
    fi
}

# 下载文件并校验
download_file() {
    local url=$1
    local output=$2
    info "正在下载：$url"
    curl -o "$output" "$url"
    if [ $? -ne 0 ] || [ ! -f "$output" ]; then
        exit_with_message "下载失败，请检查网络连接或URL是否正确。"
    fi
}

# 生成随机值函数
generate_random_token() {
    openssl rand -hex 16  # 32位随机字符串
}

generate_random_password() {
    openssl rand -base64 10 | head -c 10  # 10位随机密码
}

# 配置文件生成函数
generate_config() {
    local config_file=$1
    local component=$2

    info "开始生成 $component 配置文件..."
    read -p "使用默认配置吗？(y/n): " use_defaults

    if [[ "$use_defaults" =~ ^[Yy]$ ]]; then
        # 使用默认值
        bind_addr="0.0.0.0"
        bind_port="7000"
        bind_udp_port="7001"
        token=$(generate_random_token)
        dashboard_addr="0.0.0.0"
        dashboard_port="7500"
        dashboard_pwd=$(generate_random_password)
        vhost_https_port="443"
    else
        # 手动设置
        read -p "请输入绑定地址 (默认: 0.0.0.0): " bind_addr
        bind_addr=${bind_addr:-"0.0.0.0"}

        read -p "请输入绑定端口 (默认: 7000): " bind_port
        bind_port=${bind_port:-"7000"}

        read -p "请输入绑定 UDP 端口 (默认: 7001): " bind_udp_port
        bind_udp_port=${bind_udp_port:-"7001"}

        read -p "请输入 Token 密钥 (默认: 随机生成32位字符): " token
        token=${token:-$(generate_random_token)}

        read -p "请输入 Dashboard 地址 (默认: 0.0.0.0): " dashboard_addr
        dashboard_addr=${dashboard_addr:-"0.0.0.0"}

        read -p "请输入 Dashboard 端口 (默认: 7500): " dashboard_port
        dashboard_port=${dashboard_port:-"7500"}

        read -p "请输入 Dashboard 密码 (默认: 随机生成10位字符): " dashboard_pwd
        dashboard_pwd=${dashboard_pwd:-$(generate_random_password)}

        read -p "请输入 HTTPS 监听端口 (默认: 443): " vhost_https_port
        vhost_https_port=${vhost_https_port:-"443"}
    fi

    # 写入配置文件
    if [ -f "$config_file" ]; then
        warn "配置文件已存在，将创建备份：${config_file}.bak"
        sudo cp "$config_file" "${config_file}.bak"
    fi

    sudo tee "$config_file" > /dev/null <<EOL
[common]
bind_addr = ${bind_addr}
bind_port = ${bind_port}
bind_udp_port = ${bind_udp_port}
token = ${token}
dashboard_addr = ${dashboard_addr}
dashboard_port = ${dashboard_port}
dashboard_pwd = ${dashboard_pwd}
vhost_https_port = ${vhost_https_port}
authentication_timeout = 900
enable_p2p = true
max_pool_count = 1000
heartbeat_timeout = 120
enable_compression = true
EOL

    info "配置文件已生成：$config_file"
    info "Token：$token"
    info "Dashboard 地址：${dashboard_addr}:${dashboard_port}"
    info "Dashboard 密码：$dashboard_pwd"
}

# 安装依赖
install_dependency "curl"
install_dependency "tar"
install_dependency "systemctl"

# 获取用户选择
echo "请选择要安装的组件："
echo "1. frpc"
echo "2. frps"
read -p "输入数字 (1/2): " choice

case $choice in
    1) COMPONENT="frpc" ;;
    2) COMPONENT="frps" ;;
    *) exit_with_message "无效的选择！" ;;
esac

# 定义目录
FRP_PACKAGE_PATH="$HOME/frp.tar.gz"
INSTALL_DIR="/usr/local/bin/$COMPONENT"
CONFIG_DIR="/etc/$COMPONENT"

# 检查和下载文件
if [ ! -f "$FRP_PACKAGE_PATH" ]; then
    URL="https://github.com/fatedier/frp/releases/download/v0.50.0/frp_0.50.0_linux_amd64.tar.gz"
    download_file "$URL" "$FRP_PACKAGE_PATH"
fi

# 创建目录和解压
sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$CONFIG_DIR"
tar -xzvf "$FRP_PACKAGE_PATH" --strip-components=1 -C "$INSTALL_DIR"

# 创建 systemd 服务文件
sudo tee "/etc/systemd/system/${COMPONENT}.service" > /dev/null <<EOL
[Unit]
Description=frp $COMPONENT
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$COMPONENT -c $CONFIG_DIR/${COMPONENT}.ini
Restart=on-failure

[Install]
WantedBy=default.target
EOL

# 启动服务
sudo systemctl enable "${COMPONENT}.service"
sudo systemctl start "${COMPONENT}.service"
if ! systemctl is-active --quiet "${COMPONENT}.service"; then
    exit_with_message "服务启动失败，请检查日志！"
fi

# 生成配置文件（仅针对 frps）
if [ "$COMPONENT" == "frps" ]; then
    generate_config "$CONFIG_DIR/${COMPONENT}.ini" "$COMPONENT"
fi

# 输出安装完成信息
info "$COMPONENT 安装完成！安装目录：$INSTALL_DIR"
info "配置文件目录：$CONFIG_DIR"
info "使用以下命令管理服务："
echo "启动服务：sudo systemctl start ${COMPONENT}.service"
echo "停止服务：sudo systemctl stop ${COMPONENT}.service"
echo "重启服务：sudo systemctl restart ${COMPONENT}.service"
echo "查看状态：sudo systemctl status ${COMPONENT}.service"
