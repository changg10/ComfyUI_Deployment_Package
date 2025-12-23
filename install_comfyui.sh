#!/bin/bash

# 设置项目路径
PROJECT_DIR="$HOME/ComfyUI"  # 用户的主目录下的 ComfyUI 项目路径
VENV_DIR="$PROJECT_DIR/comfyui-env"
PORT=8188  # 定义 ComfyUI 使用的端口

# 获取当前脚本所在的目录 
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# 确保系统前提条件
echo "检查系统前提条件..."
python3 --version
pip3 --version
nvcc --version
nvidia-smi

# 检查项目目录是否存在，不存在则克隆 ComfyUI 仓库
if [ ! -d "$PROJECT_DIR" ]; then
    echo "项目目录 $PROJECT_DIR 不存在，正在克隆 ComfyUI 仓库..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$PROJECT_DIR"
else
    echo "项目目录 $PROJECT_DIR 已存在，跳过克隆..."
fi

# =================文件迁移 、自动将下载模型的脚本移动到Comfyui项目文件下=================
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

# 检查 PyTorch 是否已安装，若未安装则安装
if ! pip show torch &>/dev/null; then
    echo "安装 PyTorch CUDA 支持..."
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
else
    echo "PyTorch 已安装，跳过安装..."
fi

# 检查 ComfyUI 依赖是否已安装，若未安装则安装
if ! pip show comfyui-frontend-package &>/dev/null; then
    echo "安装 ComfyUI 依赖..."
    pip install -r requirements.txt
else
    echo "ComfyUI 依赖已安装，跳过安装..."
fi

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

# 启动 ComfyUI 服务器，并通过 0.0.0.0 绑定所有接口
echo "启动 ComfyUI 服务器..."
python main.py --listen 0.0.0.0 --port $PORT &

# 等待服务器启动并验证是否正常运行
sleep 5

# 验证服务是否正常运行
curl -I http://localhost:$PORT

echo "----------------------------------------------------------------"
echo "ComfyUI 安装部署完成！状态: $STATUS"
echo "访问地址: http://$SPARK_IP:$PORT"
echo "----------------------------------------------------------------"
echo "提示：已将 download_model.sh 移动到安装目录。"
echo "若需下载模型，请执行：cd $PROJECT_DIR && ./download_model.sh"