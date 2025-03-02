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
    local backup_url="https://co.yunzeji.cn/public/git/file"
    local output_path="./frp_package.tar.gz"
    local temp_dir="./frp_temp"
    local install_dir="/usr/local/frp_$component"
    local bin_path="$install_dir/$component"


	
	# 检查是否已安装
    if [[ -f "$bin_path" && -x "$bin_path" ]]; then
        info "$component 已安装，跳过下载。"
        return 0
    fi
	# 选择下载地址
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
# 生成随机 Token 的函数
generate_token() {
    head -c 16 /dev/urandom | base64 | tr -d '=' | tr '+/' '-_'
}
generate_password() {
    head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9!@#$%^&*()_-' | head -c 18
}
generate_frps_config() {
    local config_file="/usr/local/frp_frps/frps.ini"
    local bind_ip
    local bind_port
    local token
    local dashboard_port
    local dashboard_user
    local dashboard_pwd

    # 创建配置目录
    mkdir -p /usr/local/frp_frps

    info "请配置 FRP 服务端参数（将覆盖旧配置）："
    read -p "绑定 IP 地址（默认 0.0.0.0）：" bind_ip < /dev/tty
    bind_ip=${bind_ip:-0.0.0.0}
    read -p "服务监听端口（默认 10000）：" bind_port < /dev/tty
    bind_port=${bind_port:-10000}
   # 读取用户输入或生成随机值
   read -p "认证 Token（留空自动生成）: " token < /dev/tty
   token="${token:-$(generate_token)}"
    read -p "管理面板端口（默认 7575）：" dashboard_port < /dev/tty
    dashboard_port=${dashboard_port:-7575}
    read -p "管理用户名（默认 admin）：" dashboard_user < /dev/tty
    dashboard_user=${dashboard_user:-admin}
    read -p "管理密码（留空自动生成））：" dashboard_pwd < /dev/tty
    dashboard_pwd=${dashboard_pwd:-$(generate_password)}

    # 清空并写入新配置
    sudo tee "$config_file" > /dev/null <<EOL
[common]
bind_addr = $bind_ip
bind_port = $bind_port
token = $token
dashboard_port = $dashboard_port
dashboard_user = $dashboard_user
dashboard_pwd = $dashboard_pwd
EOL

    info "服务端配置文件已生成: $config_file"
    echo "----------------------"
    cat "$config_file"
    echo "----------------------"
}

# 生成默认配置文件
generate_frpc_config() {
    local config_file="/usr/local/frp_frpc/frpc.ini"
    local server_ip
    local server_port
    local token
    local protocol

    # 确保目录存在
    mkdir -p /usr/local/frp_frpc

    info "请提供 FRP 服务器信息（此操作将清空旧配置）："
    read -p "请输入服务器 IP 地址：" server_ip < /dev/tty
    read -p "请输入服务器端口：" server_port < /dev/tty
    read -p "请输入连接 Token：" token < /dev/tty
    read -p "请选择协议（tcp/kcp/quic，默认 tcp）：" protocol < /dev/tty
    protocol=${protocol:-tcp}  # 默认使用 TCP

    # **清空并写入新的 frpc.ini 配置**
    sudo tee "$config_file" > /dev/null <<EOL
[common]
server_addr = $server_ip
server_port = $server_port
token = $token
protocol = $protocol
EOL

    info "默认配置文件已生成: $config_file"
    echo "----------------------"
    cat "$config_file"
    echo "----------------------"
}
# 添加客户端映射
add_frpc_mapping() {
    local config_file="/usr/local/frp_frpc/frpc.ini"

    while true; do
        info "添加 FRPC 客户端映射配置"
        read -p "请输入映射名称（如 openid）：" mapping_name < /dev/tty
        read -p "请输入映射类型（tcp/udp/http/https，默认 tcp）：" mapping_type < /dev/tty
        mapping_type=${mapping_type:-tcp}
        read -p "请输入本地 IP（默认 127.0.0.1）：" local_ip < /dev/tty
        local_ip=${local_ip:-127.0.0.1}
        read -p "请输入本地端口：" local_port < /dev/tty
        read -p "请输入远程端口：" remote_port < /dev/tty

        cat >> "$config_file" <<EOL

[$mapping_name]
type = $mapping_type
local_ip = $local_ip
local_port = $local_port
remote_port = $remote_port
EOL

        info "映射 [$mapping_name] 添加成功！"

        read -p "是否继续添加映射？(y/n)：" choice < /dev/tty
        if [[ "$choice" =~ ^(n|N)$ ]]; then
            break
        fi
    done

    # **询问是否要重启 frpc 使映射生效**
    read -p "是否立即重启 FRPC 以使映射生效？(y/n)：" restart_choice < /dev/tty
    if [[ "$restart_choice" =~ ^(y|Y)$ ]]; then
        info "正在重启 FRPC..."
        sudo systemctl restart frpc
        sleep 2
        if systemctl is-active --quiet frpc; then
            info "FRPC 重启成功！"
            sudo systemctl status frpc --no-pager
        else
            error "FRPC 重启失败，请检查日志！"
            echo "查看日志：sudo journalctl -u frpc --no-pager"
        fi
    else
        warn "请手动重启 FRPC 以使新映射生效："
        echo "sudo systemctl restart frpc"
    fi
}
# 创建 systemd 服务文件
create_systemd_service() {
    local component=$1          # 服务名称，例如 "frps" 或 "frpc"
    local install_dir=$2        # 可执行文件的安装目录
    local config_file=$3        # 配置文件路径
    local description=${4:-"FRP Service"}  # 服务描述，默认为 "FRP Service"

    info "创建 systemd 服务文件..."
	 # 如果是 frpc，先生成 frpc.ini 配置
    if [[ "$component" == "frpc" ]]; then
        info "检测到 FRPC 客户端，先生成 frpc.ini 配置..."
        generate_frpc_config
    fi
	
    sudo tee "/etc/systemd/system/${component}.service" > /dev/null <<EOL
[Unit]
Description=$description
After=network.target

[Service]
Type=simple
ExecStart=$install_dir/$component -c $config_file
Restart=always
RestartSec=5
LimitNOFILE=1048576
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
    info "选择组件操作："

    while true; do
        echo "1. 下载并配置 frps（服务端）"
        echo "2. 仅下载 frpc（客户端）"
        echo "3. 添加 FRPC 客户端映射"
        echo "4. 启动 FRPS（服务端）"
		echo "5. 停止 FRPS（服务端）"
		echo "6. 重启 FRPS（服务端）"
		echo "7. 查看 FRPS（服务端）状态"
        echo "8. 启动 FRPC（客户端）"
        echo "9. 停止 FRPC（客户端）"
        echo "10. 重启 FRPC（客户端）"
        echo "11. 查看 FRPC（客户端）状态"
        read -p "请输入选项 [1-11]：" choice < /dev/tty

        case "$choice" in
            1)
                info "选择了 frps 服务端..."
                check_environment

                download_frp_package "frps"
                generate_frps_config
                create_systemd_service "frps" "/usr/local/frp_frps" "/usr/local/frp_frps/frps.ini" "FRP Server"
                info "FRPS 部署完成！"
                break
                ;;
            2)
                info "选择了 frpc 客户端..."
                check_environment
                download_frp_package "frpc"
                create_systemd_service "frpc" "/usr/local/frp_frpc" "/usr/local/frp_frpc/frpc.ini" "FRP Client"
                info "FRPC 部署完成！"
                break
                ;;
            3)
                info "选择了添加 FRPC 客户端映射..."
                add_frpc_mapping
                info "客户端映射添加完成！"
                break
                ;;		
            4)
                sudo systemctl start frps.service
                info "FRPS（服务端）已启动！"
                break
                ;;
		    5)
                sudo systemctl stop frps.service
                info "FRPS（服务端）已停止！"
                break
                ;;		
			6)
                sudo systemctl restart frps.service
                info "FRPS（服务端）已重启！"
                break
                ;;	
		   7)
                sudo systemctl status frps.service --no-pager
                break
                ;;		
				
            8)
                sudo systemctl start frpc.service
                info "FRPC（客户端）已启动！"
                break
                ;;
          
            9)
                sudo systemctl stop frpc.service
                info "FRPC（客户端）已停止！"
                break
                ;;
           
            10)
                sudo systemctl restart frpc.service
                info "FRPC（客户端）已重启！"
                break
                ;;
           
            11)
                sudo systemctl status frpc.service --no-pager
                break
                ;;
            *)
                warn "无效的选项，请重新输入！"
                ;;
        esac
    done
}

main
