#!/bin/bash

# ================================
# 自动定时运行SSH屏蔽脚本
# ================================

# 要屏蔽的登录失败次数阈值
THRESHOLD=2

# 获取当前日期和时间
DATE=$(date +"%a %b %e %H")

# 获取登录失败次数超过阈值的IP地址
ABNORMAL_IP=$(lastb | grep "$DATE" | awk -v threshold="$THRESHOLD" '{a[$3]++}END{for(i in a)if(a[i]>threshold)print i}')

# 遍历处理每个异常的IP地址
for IP in $ABNORMAL_IP; do
    # 检查IP是否已在黑名单中
    if ! grep -q "$IP" /etc/hosts.deny; then
        echo "屏蔽IP：$IP"
        echo "sshd:$IP" >> /etc/hosts.deny
    else
        echo "IP：$IP 已存在系统黑名单中"
    fi
done

# 重启SSH服务
if command -v systemctl &> /dev/null; then
    systemctl restart ssh
elif command -v service &> /dev/null; then
    service ssh restart
else
    echo "无法确定如何重启SSH服务"
fi

echo "屏蔽完成"

# 添加定时任务到crontab，每分钟执行一次
(crontab -l 2>/dev/null; echo "* * * * * $(realpath $0)") | crontab -

exit 0
