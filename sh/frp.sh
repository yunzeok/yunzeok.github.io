#!/bin/bash
# -*- coding: utf-8 -*-
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

# 安装缺失的依赖
install_dependency() {
    local package=$1
    if ! command -v "$package" &> /dev/null; then
        info "安装缺失依赖: $package"
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y "$package" || exit_with_message "$package 安装失败！"
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y "$package" || exit_with_message "$package 安装失败！"
        else
            exit_with_message "无法识别系统，请手动安装 $package。"
        fi
    fi
}

# 检查系统环境
check_environment() {
    if [ -f /etc/debian_version ]; then
        info "检测到 Debian/Ubuntu 系统"
    elif [ -f /etc/redhat-release ]; then
        info "检测到 RedHat 系统"
    else
        exit_with_message "无法识别的系统类型，请检查支持情况。"
    fi

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            info "检测到 x86 架构"
            ;;
        aarch64)
            info "检测到 ARM 架构"
            ;;
        *)
            exit_with_message "不支持的架构类型: $ARCH"
            ;;
    esac

    install_dependency "curl"
    install_dependency "tar"
}

# 下载并解压 FRP
download_frp_package() {
    local component=$1
    local version="0.51.3"
    local arch=$(uname -m)
    local primary_url=""
    local backup_url="https://min.zeihaoxue.cn/public/git/file"
    local output_path="./frp_package.tar.gz"
    local temp_dir="./frp_temp"
    local install_dir="/usr/local/frp_$component"

    case "$arch" in
        x86_64)
            primary_url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_amd64.tar.gz"
            backup_url="${backup_url}/frp_${version}_linux_amd64.tar.gz"
            ;;
        aarch64)
            primary_url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_arm64.tar.gz"
            backup_url="${backup_url}/frp_${version}_linux_arm64.tar.gz"
            ;;
        *)
            exit_with_message "不支持的架构类型: $arch"
            ;;
    esac

    info "尝试从 GitHub 下载 $component..."
    curl -Lo "$output_path" "$primary_url" || {
        warn "从 GitHub 下载失败，尝试备用地址..."
        curl -Lo "$output_path" "$backup_url" || exit_with_message "备用地址下载失败！"
    }

    info "下载完成，准备解压到临时目录：$temp_dir"
    mkdir -p "$temp_dir" || exit_with_message "创建临时目录失败：$temp_dir"
    tar -xzvf "$output_path" -C "$temp_dir" || exit_with_message "解压失败，请检查文件完整性！"

    info "准备移动 $component 文件到目标目录：$install_dir"
    sudo mkdir -p "$install_dir" || exit_with_message "创建目标目录失败：$install_dir"
    sudo mv "$temp_dir"/*/* "$install_dir" || exit_with_message "移动文件失败！"
    sudo chmod +x "$install_dir/$component" || exit_with_message "设置可执行权限失败！"

    info "$component 下载并解压完成！文件位于：$install_dir"
    rm -rf "$temp_dir" "$output_path"
}

# 创建 systemd 服务文件
create_systemd_service() {
    local component=$1          # 服务名称，例如 "frps" 或 "frpc"
    local install_dir=$2        # 可执行文件的安装目录
    local config_file=$3        # 配置文件路径
    local description=${4:-"FRP Service"}  # 服务描述，默认为 "FRP Service"

    info "创建 systemd 服务文件..."
    sudo tee "/etc/systemd/system/${component}.service" > /dev/null <<EOL
[Unit]
Description=$description
After=network.target

[Service]
Type=simple
ExecStart=$install_dir/$component -c $config_file
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    info "是否启用并启动服务？"
    read -p "请输入 [y/yes] 启用并启动服务，其他值跳过启动步骤：" choice < /dev/tty
    choice=${choice:-n}

    if [[ "$choice" =~ ^(y|yes)$ ]]; then
        info "启用并启动服务..."
        sudo systemctl enable "${component}.service"
        sudo systemctl start "${component}.service"

        if systemctl is-active --quiet "${component}.service"; then
            info "服务启动成功！"
            echo "当前服务状态："
            sudo systemctl status "${component}.service" --no-pager
        else
            error "服务启动失败！请检查日志。"
            echo "查看日志：sudo journalctl -u ${component}.service"
        fi
    else
        warn "跳过服务启动步骤，您可以稍后手动启动服务。"
        echo "如需启动服务，请运行以下命令："
        echo "sudo systemctl start ${component}.service"
    fi
}

# 主程序入口
main() {
    info "选择组件类型："

    # 循环直到用户输入有效选项
    while true; do
        echo "1. 下载并配置 frps（服务端）"
        echo "2. 仅下载 frpc（客户端）"
        read -p "请输入选项 [1/2]：" choice < /dev/tty

        case "$choice" in
            1)
                info "选择了 frps 服务端..."
                check_environment
                download_frp_package "frps"
                create_systemd_service "frps" "/usr/local/frp_frps" "/usr/frp/frps.ini" "FRP Server"
                info "FRPS 部署完成！"
                break
                ;;
            2)
                info "选择了 frpc 客户端..."
                check_environment
                download_frp_package "frpc"
                create_systemd_service "frpc" "/usr/local/frp_frpc" "/usr/local/frpc.ini" "FRP Client"
                info "FRPC 部署完成！"
                break
                ;;
            *)
                warn "无效的选项，请重新输入！"
                ;;
        esac
    done
}

main
