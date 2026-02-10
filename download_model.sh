#!/bin/bash
# =================================================================
# Script Name: download_model.sh
# Description: DGX Spark 环境 ComfyUI 智能模型下载工具
#              集成路径自动映射与错误修正功能
# Version:     v3.0 (Smart Map & Dynamic Create)
# Author:      昌国庆 (Leadtek)
# Date:        2026-02-10
# =================================================================



function show_usage {
    echo "================================================================"
    echo "用法: $0 <下载链接> <类别代码 或 文件夹名称>"
    echo "----------------------------------------------------------------"
    echo "1. 快捷代码示例 (自动映射):"
    echo "   ckpt -> models/checkpoints | lora -> models/loras"
    echo "   vae  -> models/vae         | cn   -> models/controlnet"
    echo "2. 自定义名称示例 (自动创建):"
    echo "   $0 <URL> insightface  --> 下载到 models/insightface/"
    echo "   $0 <URL> my_folder    --> 下载到 models/my_folder/"
    echo "================================================================"
}

if [ $# -ne 2 ]; then
    show_usage
    exit 1
fi

DOWNLOAD_URL=$1
INPUT_PARAM=$2
PROJECT_DIR="$(pwd)"

# --- 1. 核心逻辑：智能路径解析 ---
INPUT_LOWER=$(echo "$INPUT_PARAM" | tr '[:upper:]' '[:lower:]')

case "$INPUT_LOWER" in
    "ckpt" | "checkpoint" | "checkpoints")
        TARGET_REL_PATH="models/checkpoints"
        ;;
    "lora" | "loras")
        TARGET_REL_PATH="models/loras"
        ;;
    "cv" | "clip" | "clip_vision" | "clipvision")
        TARGET_REL_PATH="models/clip_vision"
        ;;
    "vae")
        TARGET_REL_PATH="models/vae"
        ;;
    "cn" | "controlnet")
        TARGET_REL_PATH="models/controlnet"
        ;;
    "unet" | "diffusion")
        TARGET_REL_PATH="models/unet"
        ;;
    "upscale" | "esrgan")
        TARGET_REL_PATH="models/upscale_models"
        ;;
    *)
        # 场景：用户输入的是自定义类别或文件夹名
        # 移除可能误输入的路径斜杠和文件名后缀
        CLEAN_PARAM=$(echo "$INPUT_PARAM" | sed 's/\///g' | sed 's/\.safetensors//g' | sed 's/\.pth//g')
        
        # 检查是否已经是 models/ 开头的路径
        if [[ "$INPUT_PARAM" == "models/"* ]]; then
            TARGET_REL_PATH="$INPUT_PARAM"
        else
            TARGET_REL_PATH="models/$CLEAN_PARAM"
        fi
        ;;
esac

# --- 2. 目录准备 ---
MODEL_SAVE_DIR="$PROJECT_DIR/$TARGET_REL_PATH"

if [ -f "$MODEL_SAVE_DIR" ]; then
    echo "❌ 错误: $MODEL_SAVE_DIR 是一个文件，无法作为目录使用。"
    exit 1
fi

if [ ! -d "$MODEL_SAVE_DIR" ]; then
    echo "📁 目录不存在，正在自动创建: $TARGET_REL_PATH"
    mkdir -p "$MODEL_SAVE_DIR"
fi

# --- 3. 文件名处理 (处理带参数的 URL) ---
# 提取文件名并去除 URL 问号后的参数
FILE_NAME=$(basename "${DOWNLOAD_URL%%\?*}")
SAVE_PATH="$MODEL_SAVE_DIR/$FILE_NAME"

# --- 4. 执行下载 ---
echo "----------------------------------------------------------------"
echo "🚀 正在下载..."
echo "🔗 来源: $DOWNLOAD_URL"
echo "📂 目标: $TARGET_REL_PATH/"
echo "📄 文件: $FILE_NAME"
echo "----------------------------------------------------------------"

wget --continue --progress=bar:force "$DOWNLOAD_URL" -O "$SAVE_PATH"

# --- 5. 结果校验 ---
if [ $? -eq 0 ]; then
    echo "----------------------------------------------------------------"
    echo "✅ 下载成功！"
    echo "📍 路径: $SAVE_PATH"
else
    echo "❌ 下载失败，请检查网络或链接是否有效。"
    # 如果下载失败且文件夹是空的，可以考虑删除它（可选）
    exit 1
fi
