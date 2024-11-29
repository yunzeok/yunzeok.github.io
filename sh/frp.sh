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

# 下载文件函数
download_file() {
    local url=$1
    local output=$2
    info "尝试下载：$url"
    curl -o "$output" --connect-timeout 10 --retry 3 "$url"
    if [ $? -ne 0 ] || [ ! -f "$output" ]; then
        exit_with_message "下载失败，请检查网络连接或URL是否正确。"
    fi

    # 校验文件是否为有效压缩包
    if ! tar -tzf "$output" &> /dev/null; then
        rm -f "$output" # 删除损坏的文件
        exit_with_message "文件校验失败，请重试或更换下载源。"
    fi
    info "文件下载并校验成功：$output"
}

# 解压文件函数
extract_file() {
    local file=$1
    local dest=$2
    info "正在解压文件：$file"
    tar -xzvf "$file" --strip-components=1 -C "$dest"
    if [ $? -ne 0 ]; then
        exit_with_message "解压失败，请检查压缩包是否损坏。"
    fi
    info "文件解压成功：$dest"
}

# 安装依赖
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

# 主程序逻辑
main() {
    # 安装必要的依赖
    install_dependency "curl"
    install_dependency "tar"
    install_dependency "systemctl"

    # 获取用户选择
    echo "请 选 择 要 安 装 的 组 件 ："
    echo "1. frpc"
    echo "2. frps"
    read -p "输 入 数 字  (1/2): " choice

    case $choice in
        1) COMPONENT="frpc" ;;
        2) COMPONENT="frps" ;;
        *) exit_with_message "无效的选择！" ;;
    esac

    echo "请选择下载选项："
    echo "1. 最新版"
    echo "2. 特定版本（V0.50.0）"
    echo "3. ARM 版本"
    read -p "输入数字 (1/2/3): " download_choice

    # 定义目录和变量
    FRP_PACKAGE_PATH="$HOME/frp.tar.gz"
    INSTALL_DIR="/usr/local/bin/$COMPONENT"
    CONFIG_DIR="/etc/$COMPONENT"
    VERSION="0.50.0" # 默认版本号，用于最新版下载

    # 根据用户选择设置下载地址
    case $download_choice in
        1)
            URL="https://github.com/fatedier/frp/releases/download/v${VERSION}/frp_${VERSION}_linux_amd64.tar.gz"
            AUTO_CONFIG="false" # 最新版无法自动生成配置文件
            ;;
        2)
            URL="https://yunzeo.github.io/download/old/frp.tar.gz"
            AUTO_CONFIG="true"
            ;;
        3)
            URL="https://yunzeo.github.io/download/old/arm/frp.tar.gz"
            AUTO_CONFIG="true"
            ;;
        *)
            exit_with_message "无效的选择！"
            ;;
    esac

    # 下载文件
    if [ ! -f "$FRP_PACKAGE_PATH" ]; then
        info "文件未找到，开始下载..."
        download_file "$URL" "$FRP_PACKAGE_PATH"
    else
        info "本地已存在下载文件：$FRP_PACKAGE_PATH，跳过下载。"
    fi

    # 创建目录和解压
    sudo mkdir -p "$INSTALL_DIR"
    sudo mkdir -p "$CONFIG_DIR"
    extract_file "$FRP_PACKAGE_PATH" "$INSTALL_DIR"

    # 根据是否支持自动生成配置文件输出提示
    if [ "$AUTO_CONFIG" = "true" ]; then
        # 创建默认配置文件
        sudo tee "$CONFIG_DIR/${COMPONENT}.ini" > /dev/null <<EOL
[common]
server_addr = 127.0.0.1
server_port = 7000
EOL
        info "已生成默认配置文件：$CONFIG_DIR/${COMPONENT}.ini，请根据需要修改。"
    else
        warn "由于选择了最新版，无法自动生成配置文件。"
        warn "请手动在 $CONFIG_DIR 目录下创建配置文件 ${COMPONENT}.ini。"
    fi

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

    # 输出安装完成信息
    info "$COMPONENT 安装完成！安装目录：$INSTALL_DIR"
    info "配置文件目录：$CONFIG_DIR"
    info "使用以下命令管理服务："
    echo "启动服务：sudo systemctl start ${COMPONENT}.service"
    echo "停止服务：sudo systemctl stop ${COMPONENT}.service"
    echo "重启服务：sudo systemctl restart ${COMPONENT}.service"
    echo "查看状态：sudo systemctl status ${COMPONENT}.service"
}

main
