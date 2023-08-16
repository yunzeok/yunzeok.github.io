#!/bin/env bash

# 检查当前使用的 Linux 发行版类型
os_type=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

# 检查 Git 是否已经安装
if ! command -v git &> /dev/null
then
    echo "Git 还没有安装。"

    # 安装 Git
    echo "安装 Git..."
    if echo "$os_type" | grep -q "Ubuntu"; then
        sudo apt-get update
        sudo apt-get install -y git
    elif echo "$os_type" | grep -q "CentOS Linux"; then
        sudo yum update -y
        sudo yum install git -y
    else
        echo "你的操作系统不支持 Git 的自动安装。"
        exit 1
    fi

    echo "Git 安装成功！"
else
    echo "Git 已经安装。"
fi

# 检查 Docker 是否已经安装
if ! command -v docker &> /dev/null
then
    echo "Docker 还没有安装。"

    # 安装 Docker
    echo "安装 Docker..."
    curl -sSL https://get.docker.com/ | sudo sh
    echo "Docker 安装成功！"

    # 启动 Docker 服务并设置开机自启
    echo "启动 Docker 服务..."
    sudo systemctl start docker
    sudo systemctl enable docker.service
    echo "Docker 服务启动成功！"
else
    echo "Docker 已经安装。"
fi

# 检查用户的 root 文件夹下是否有 chatbot-ui 文件夹
if [[ -d "$HOME/chatbot-ui" ]]; then
    echo "已存在 chatbot-ui 文件夹，无需克隆。"
else
    # 在当前的bash环境下从 GitHub 克隆项目
    echo "正在从 GitHub 克隆项目..."
    cd $HOME
    git clone https://github.com/mckaywrigley/chatbot-ui.git
    echo "成功克隆了仓库。"
    cd $HOME/chatbot-ui
    sudo docker build -t chatgpt-ui .
    echo "成功构建chatgpt-ui"
fi

# 让用户输入 OpenAI API 密钥
echo "请输入你的 OpenAI API Key:"
read OPENAI_API_KEY

# 让用户从列表中选择模型
echo "请从列表中选择一个模型:"
echo "1. gpt-3.5-turbo"
echo "2. gpt-35-turbo"
echo "3. gpt-4"
echo "4. gpt-4-32k"
echo "如果直接回车将使用默认模型 gpt-4-32k:"
read MODEL_NUMBER

# 根据输入选择模型
case $MODEL_NUMBER in
    "1")
        MODEL="gpt-3.5-turbo"
        ;;
    "2")
        MODEL="gpt-35-turbo"
        ;;
    "3")
        MODEL="gpt-4"
        ;;
    "4")
        MODEL="gpt-4-32k"
        ;;
    *)
        MODEL="gpt-4-32k"
        ;;
esac

# 设置默认的 Docker 端口
DOCKER_PORT=3100

# Find the Docker container id that is using the specified port
container_id=$(docker ps --format '{{.ID}}:{{.Ports}}' | grep $DOCKER_PORT | cut -d ':' -f 1)

if [[ -n "$container_id" ]]; then
    echo "Docker 容器（ID: $container_id）正在使用端口 $DOCKER_PORT。"

    # 问用户是否想停止正在使用该端口的服务
    read -p "你想停止使用此端口的 Docker 容器吗? (yes/no, 默认为是): " stop_container
    stop_container=${stop_container:-yes}

    if [[ $stop_container == "yes" ]]; then
        echo "正在停止 Docker 容器..."
        sudo docker stop $container_id
        echo "Docker 容器已停止."
    else
        # 提示用户输入新的 Docker 端口
        read -p "请输入新的 Docker 端口: " new_port
        DOCKER_PORT=${new_port:-$DOCKER_PORT}
    fi
else
    echo "端口 $DOCKER_PORT 当前未被 Docker 容器使用。"
fi

# 检查 screen 是否已经安装
if ! command -v screen &> /dev/null
then
    echo "screen 还没有安装。"

    # 根据操作系统类型安装 screen
    echo "安装 screen..."

    if echo "$os_type" | grep -q "Ubuntu"; then
        sudo apt-get update
        sudo apt-get install -y screen
    elif echo "$os_type" | grep -q "CentOS Linux"; then
        sudo yum update -y
        sudo yum install screen -y
    else
        echo "你的操作系统不支持 screen 的自动安装。"
        exit 1
    fi

    echo "screen 安装成功！"
else
    echo "screen 已经安装。"
fi

echo "开始在后台运行新的 screen 会话..."
echo "在端口 $DOCKER_PORT 上运行 Docker 容器..."
echo "你可以按 Ctrl-a 然后 d 来退出 screen 会话，并让它在后台继续运行。"
echo "如果你想再次进入 screen 会话，可以运行 'screen -r chatgpt' 命令。"
screen -dmS chatgpt bash -c "sudo docker run -e OPENAI_API_KEY=$OPENAI_API_KEY -e DEFAULT_MODEL=$MODEL -p $DOCKER_PORT:3000 chatgpt-ui"