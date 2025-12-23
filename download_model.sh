#!/bin/bash

# 检查是否提供了下载链接和目标文件夹路径
if [ $# -ne 2 ]; then
    echo "Usage: $0 <download_url> <target_folder>"
    echo "Example: $0 https://huggingface.co/xxx/yyy.safetensors diffusion_models/"
    exit 1
fi

# 获取用户输入的下载链接和目标文件夹
DOWNLOAD_URL=$1
TARGET_FOLDER=$2

# 自动获取当前脚本所在目录（ComfyUI 项目目录）
PROJECT_DIR="$(pwd)"

# 设置模型保存路径
MODEL_SAVE_PATH="$PROJECT_DIR/$TARGET_FOLDER"

# 检查目标文件夹是否存在，如果不存在则创建
if [ ! -d "$MODEL_SAVE_PATH" ]; then
    echo "目标文件夹 $TARGET_FOLDER 不存在，正在创建..."
    mkdir -p "$MODEL_SAVE_PATH"
else
    echo "目标文件夹 $TARGET_FOLDER 已存在，继续下载..."
fi

# 从 URL 中提取文件名（文件名为 URL 的最后部分）
FILE_NAME=$(basename "$DOWNLOAD_URL")

# 完整的保存路径
SAVE_PATH="$MODEL_SAVE_PATH/$FILE_NAME"

# 使用 wget 下载文件，支持断点续传
echo "开始下载文件 $FILE_NAME 到 $SAVE_PATH ..."
wget --continue --progress=bar:force "$DOWNLOAD_URL" -O "$SAVE_PATH"

# 检查下载是否成功
if [ $? -eq 0 ]; then
    echo "文件下载完成：$SAVE_PATH"
else
    echo "下载失败，请检查链接或网络连接。"
    exit 1
fi

# 完成提示
echo "模型文件 $FILE_NAME 已下载并保存到 $SAVE_PATH"
