#!/bin/bash

# 指定公钥内容，替换为你自己的公钥
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDA6P97uQ7S2J8TR919GJpRrHlMKsCSOFlCK8WVaZNSmf+huS8oxQVuz8N12MsRD2Kog42B9gS2ymmwbmXl/iV4xJ3YVmv/NkCAb2B1ZoK+Zj2c3/6Jdlu6HcSH4cSJhY5gLOk4ac5tPFFKkpwNe95p7whinkNrSGNV143wfmZDZs9MDYFhmfZwKsLoQi6PQGtivixa1uwZDw0ziUiC+JfWQXFBGOuX3pUB2hY+zJECYx2cK9p+LfF+vgkVxkLXyTvpbSnnfpIaeFL4em8a7PGBaoJysuGG0MuqiaCMB/eP7BNlEEi5Ryud8ci8+Akgl+3AyXjSUqzkUyhQiJ+xy4AP9JM5O5dNZY0poTINvfPd1VEs5BRusakJoIc9uS1W2WHlSF4rK3CpId4iq+ZH2UHQV4584UlT97snAtPjVehSuvfTRj5mf4bl8nhrNs9d6Oy/IsOP379iyxsfGE5iVXrGjj6J9KoCTn76Y2aqvnLRbtIlPFbO3K6A6SG2BWs/g00="

# 确保 .ssh 目录存在
if [ ! -d ~/.ssh ]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
fi

# 将公钥添加到 authorized_keys 文件中，若已存在则替换
if grep -q "$PUBLIC_KEY" ~/.ssh/authorized_keys 2>/dev/null; then
    sed -i "/$PUBLIC_KEY/d" ~/.ssh/authorized_keys
    echo "公钥已存在，将替换旧的公钥。"
fi
echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "公钥已添加到 authorized_keys 文件中"

# 配置 SSH 以允许公钥登录
SSH_CONFIG_FILE="/etc/ssh/sshd_config"

# 备份 SSH 配置文件
if [ ! -f "$SSH_CONFIG_FILE.bak" ]; then
    cp $SSH_CONFIG_FILE $SSH_CONFIG_FILE.bak
    echo "已备份 $SSH_CONFIG_FILE 到 $SSH_CONFIG_FILE.bak"
fi

# 确保配置允许公钥登录
sed -i 's/#*PubkeyAuthentication no/PubkeyAuthentication yes/' $SSH_CONFIG_FILE
sed -i 's/#*PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG_FILE

# 选择是否禁用密码登录
echo "是否禁用密码登录？（默认不禁用）"
echo "按 'y' 确认禁用，按 'n' 或等待 10 秒以跳过此步骤。"
read -t 10 -n 1 -p "选择 (y/n): " disable_password_login

# 超时或选择 'n' 的默认操作
if [ "$disable_password_login" == "y" ]; then
    sed -i 's/#*PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG_FILE
    echo -e "\n已禁用密码登录，仅允许公钥登录。"
else
    echo -e "\n保留密码登录。"
fi

# 重启SSH服务以应用更改
if systemctl status ssh >/dev/null 2>&1; then
    systemctl restart ssh
    echo "SSH 服务已重启"
elif systemctl status sshd >/dev/null 2>&1; then
    systemctl restart sshd
    echo "SSH 服务已重启"
else
    service ssh restart
    echo "SSH 服务已重启"
fi

echo "SSH 配置已更新，公钥登录已启用。"
