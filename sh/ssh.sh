#!/usr/bin/env bash

set -euo pipefail

# 配置常量
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDA6P97uQ7S2J8TR919GJpRrHlMKsCSOFlCK8WVaZNSmf+huS8oxQVuz8N12MsRD2Kog42B9gS2ymmwbmXl/iV4xJ3YVmv/NkCAb2B1ZoK+Zj2c3/6Jdlu6HcSH4cSJhY5gLOk4ac5tPFFKkpwNe95p7whinkNrSGNV143wfmZDZs9MDYFhmfZwKsLoQi6PQGtivixa1uwZDw0ziUiC+JfWQXFBGOuX3pUB2hY+zJECYx2cK9p+LfF+vgkVxkLXyTvpbSnnfpIaeFL4em8a7PGBaoJysuGG0MuqiaCMB/eP7BNlEEi5Ryud8ci8+Akgl+3AyXjSUqzkUyhQiJ+xy4AP9JM5O5dNZY0poTINvfPd1VEs5BRusakJoIc9uS1W2WHlSF4rK3CpId4iq+ZH2UHQV4584UlT97snAtPjVehSuvfTRj5mf4bl8nhrNs9d6Oy/IsOP379iyxsfGE5iVXrGjj6J9KoCTn76Y2aqvnLRbtIlPFbO3K6A6SG2BWs/g00= $(whoami)@$(hostname)"
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
SSH_DIR="${HOME}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

# 检查系统是否为Debian系列
if ! grep -q -E '^(ID=debian|ID=ubuntu)' /etc/os-release 2>/dev/null; then
    echo "错误：此脚本仅适用于Debian系列系统（Debian/Ubuntu）" >&2
    exit 1
fi

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo "错误：此脚本必须以 root 身份运行" >&2
    exit 1
fi

# 解析命令行选项
NON_INTERACTIVE=false
while getopts ":y" opt; do
    case $opt in
        y)
            NON_INTERACTIVE=true
            ;;
        \?)
            echo "无效选项: -$OPTARG" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

# 确保 .ssh 目录存在
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# 安全地处理公钥
escape_regex() {
    echo "$1" | sed 's/[][\.*^$]/\\&/g'
}

key_regex=$(escape_regex "$PUBLIC_KEY")

# 添加或替换公钥
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
grep -qF "$PUBLIC_KEY" "$AUTH_KEYS" && ACTION="替换" || ACTION="添加"
sed -i "/$key_regex/d" "$AUTH_KEYS" 2>/dev/null || true
echo "$PUBLIC_KEY" >> "$AUTH_KEYS"
echo "公钥已${ACTION}到 authorized_keys 文件"

# 备份SSH配置
backup_file() {
    local file=$1
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup="${file}.bak.${timestamp}"
    cp "$file" "$backup"
    echo "已备份 $file 到 $backup"
}

[[ -f "$SSH_CONFIG_FILE" ]] && backup_file "$SSH_CONFIG_FILE"

# 配置SSH - 使用不同的分隔符避免冲突
update_ssh_config() {
    local key=$1
    local value=$2
    
    # 使用 | 作为分隔符避免路径中的 / 干扰
    if grep -q "^$key" "$SSH_CONFIG_FILE"; then
        sed -i "s|^$key.*|$key $value|" "$SSH_CONFIG_FILE"
    elif grep -q "^#$key" "$SSH_CONFIG_FILE"; then
        sed -i "s|^#$key.*|$key $value|" "$SSH_CONFIG_FILE"
    else
        echo "$key $value" >> "$SSH_CONFIG_FILE"
    fi
}

# 确保密钥登录始终启用
update_ssh_config "PubkeyAuthentication" "yes"
echo "已启用密钥登录"

# 确保公钥文件位置正确 - 使用不同的分隔符避免冲突
update_ssh_config "AuthorizedKeysFile" ".ssh/authorized_keys"

# 允许root远程登录
update_ssh_config "PermitRootLogin" "yes"
echo "已允许root远程登录"

# 密码登录配置（默认禁用）
if $NON_INTERACTIVE; then
    # 非交互模式，直接禁用密码登录
    update_ssh_config "PasswordAuthentication" "no"
    echo "非交互模式：已禁用密码登录"
else
    # 交互模式，默认禁用密码登录
    echo -e "\n是否禁用密码登录？(默认: 禁用) [Y/n]"
    read -t 15 -n 1 -p "请选择: " disable_password_login
    echo

    # 将用户输入转换为小写
    disable_password_login=${disable_password_login,,}
    
    # 默认情况（包括回车）视为Y
    if [[ "$disable_password_login" == "n" ]]; then
        update_ssh_config "PasswordAuthentication" "yes"
        echo "已启用密码登录"
    else
        update_ssh_config "PasswordAuthentication" "no"
        echo "已禁用密码登录，仅允许公钥登录"
    fi
fi

# 配置其他安全选项
update_ssh_config "ChallengeResponseAuthentication" "no"
update_ssh_config "PermitEmptyPasswords" "no"
echo "已配置额外安全选项"

# 重启SSH服务 - 简化处理
restart_ssh() {
    if command -v systemctl >/dev/null; then
        # 尝试常见服务名称
        if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
            echo "SSH服务已重启"
            return 0
        fi
    fi
    
    # 尝试传统service命令
    if command -v service >/dev/null; then
        if service ssh restart 2>/dev/null || service sshd restart 2>/dev/null; then
            echo "SSH服务已重启"
            return 0
        fi
    fi
    
    # 如果都失败则报错
    echo "错误：无法重启SSH服务，请手动执行以下命令之一：" >&2
    echo "  systemctl restart ssh" >&2
    echo "  systemctl restart sshd" >&2
    echo "  service ssh restart" >&2
    return 1
}

if restart_ssh; then
    echo "SSH配置已更新"
    echo "公钥登录: 已启用"
    echo "root远程登录: 已允许"
    echo "密码登录: $(grep -i "^PasswordAuthentication" $SSH_CONFIG_FILE | awk '{print $2}')"
    
    echo -e "\n重要提示：请保持当前连接，在新窗口测试SSH连接"
    echo "确认连接正常后再关闭当前会话"
    
    echo -e "\n当前安全配置:"
    grep -E "^(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin|ChallengeResponseAuthentication|PermitEmptyPasswords)" $SSH_CONFIG_FILE
else
    echo "SSH配置已更新，但需要手动重启服务" >&2
fi
