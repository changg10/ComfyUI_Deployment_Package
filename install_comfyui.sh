#!/bin/bash
# =================================================================
# Script Name: install_comfyui.sh
# Description: DGX Spark 环境 ComfyUI 离线部署脚本 (基于 Zip 包)
# Version:     v2.2 (Modified for Zip Deployment)
# Author:      昌国庆 (Leadtek)
# Date:        2025-12-23
# =================================================================

# 获取当前脚本所在的目录
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# 设置项目路径
PROJECT_DIR="$HOME/ComfyUI"  # 解压后的目标路径
ZIP_FILE="$SCRIPT_DIR/ComfyUI.zip" # Zip 包位置
VENV_DIR="$PROJECT_DIR/comfyui-env"
PORT=8188  # 定义 ComfyUI 使用的端口

# ================= 1. 系统环境检查与准备 =================
echo "=== 1. 检查系统前提条件 ==="

# 检查 unzip 工具是否安装
if ! command -v unzip &> /dev/null; then
    echo "未找到 unzip 工具，正在尝试安装..."
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update && sudo apt-get install -y unzip
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y unzip
    else
        echo "错误: 无法自动安装 unzip，请手动安装后重试。"
        exit 1
    fi
fi

python3 --version
pip3 --version
nvcc --version
nvidia-smi

# ================= 2. 解压项目文件 =================
echo "=== 2. 部署项目文件 ==="

# 检查项目目录是否存在
if [ ! -d "$PROJECT_DIR" ]; then
    echo "项目目录 $PROJECT_DIR 不存在，准备解压..."
    
    # 检查 Zip 文件是否存在
    if [ -f "$ZIP_FILE" ]; then
        echo "正在解压 $ZIP_FILE 到 $HOME ..."
        # -q 为安静模式，-o 为覆盖模式，-d 指定目录
        unzip -q -o "$ZIP_FILE" -d "$HOME"
        
        # 二次确认解压结果（防止zip包内没有根文件夹的情况）
        if [ ! -d "$PROJECT_DIR" ]; then
             echo "警告: 解压后未发现 $PROJECT_DIR 目录。请检查 zip 包结构是否包含 'ComfyUI' 根文件夹。"
             # 可选：如果zip里直接是散乱文件，可能需要手动创建目录逻辑，视您的压缩包结构而定
        else
             echo "解压成功！"
        fi
    else
        echo "错误: 在 $SCRIPT_DIR 下未找到 ComfyUI.zip 文件！"
        exit 1
    fi
else
    echo "项目目录 $PROJECT_DIR 已存在，跳过解压..."
fi

# ================= 3. 文件迁移 =================
echo "=== 3. 迁移辅助脚本 ==="
# 检查源文件是否存在，并将其复制到 PROJECT_DIR
if [ -f "$SCRIPT_DIR/download_model.sh" ]; then
    echo "发现 download_model.sh，正在移动至 $PROJECT_DIR ..."
    cp "$SCRIPT_DIR/download_model.sh" "$PROJECT_DIR/"
    chmod +x "$PROJECT_DIR/download_model.sh"  # 赋予执行权限
    echo "成功：download_model.sh 已移动并赋予执行权限。"
else
    echo "警告：在 $SCRIPT_DIR 下未找到 download_model.sh，跳过迁移。"
fi

# 进入项目目录
cd "$PROJECT_DIR"

# ================= 4. 环境配置与依赖安装 =================
echo "=== 4. 配置虚拟环境与依赖 ==="

# 检查虚拟环境是否已存在，若不存在则创建
if [ ! -d "$VENV_DIR" ]; then
    echo "虚拟环境不存在，正在创建..."
    python3 -m venv comfyui-env
else
    echo "虚拟环境已存在，跳过创建..."
fi

# 激活虚拟环境
source comfyui-env/bin/activate

# 配置国内镜像源
echo "配置国内镜像源..."
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn

# 检查 PyTorch 是否已安装
if ! pip show torch &>/dev/null; then
    echo "安装 PyTorch CUDA 支持..."
    # 注意：如果是纯离线环境，这里可能需要改为 pip install --no-index --find-links=./wheels torch...
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
else
    echo "PyTorch 已安装，跳过安装..."
fi

# 检查 ComfyUI 依赖
if ! pip show comfyui-frontend-package &>/dev/null; then
    echo "安装 ComfyUI 依赖..."
    pip install -r requirements.txt
else
    echo "ComfyUI 依赖已安装，跳过安装..."
fi

# ================= 5. 服务启动 =================
echo "=== 5. 启动服务 ==="

# 自动检测并解决端口占用问题
echo "检查端口 $PORT 是否被占用..."
if sudo lsof -i :$PORT &>/dev/null; then
    echo "端口 $PORT 已被占用，正在释放..."
    sudo fuser -k $PORT/tcp  # 强制释放端口
else
    echo "端口 $PORT 可用，继续启动 ComfyUI..."
fi

# 获取主机 IP 地址
SPARK_IP=$(hostname -I | awk '{print $1}')

# 启动 ComfyUI 服务器
echo "启动 ComfyUI 服务器..."
# nohup 让进程在后台运行，即使终端关闭也不退出 (建议生产环境使用 nohup)
nohup python main.py --listen 0.0.0.0 --port $PORT > comfyui.log 2>&1 &

# 等待服务器启动并验证是否正常运行
echo "正在等待服务启动..."
sleep 5

# 验证服务是否正常运行
if curl -I http://localhost:$PORT &>/dev/null; then
    STATUS="运行中 (Running)"
else
    STATUS="启动可能延迟或失败，请查看 comfyui.log"
fi

echo "----------------------------------------------------------------"
echo "ComfyUI 安装部署完成！状态: $STATUS"
echo "访问地址: http://$SPARK_IP:$PORT"
echo "日志文件: $PROJECT_DIR/comfyui.log"
echo "----------------------------------------------------------------"
echo "提示：已将 download_model.sh 移动到安装目录。"
echo "若需下载模型，请执行：cd $PROJECT_DIR && ./download_model.sh"