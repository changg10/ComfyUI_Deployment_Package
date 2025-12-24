#!/bin/bash
# =================================================================
# Script Name: download_model.sh
# Description: DGX Spark 环境 ComfyUI 智能模型下载工具
#              集成路径自动映射与错误修正功能
# Version:     v2.2 (Auto-Map & Fix)
# Author:      昌国庆 (Leadtek)
# Date:        2025-12-24
# =================================================================

# --- 1. 定义帮助信息 ---
function show_usage {
    echo "================================================================"
    echo "Usage: $0 <下载链接> <模型类型 或 目标路径>"
    echo "----------------------------------------------------------------"
    echo "参数 2 推荐使用以下【类型代码】，脚本会自动定位路径："
    echo "  ckpt   -> 主模型 (models/checkpoints)"
    echo "  lora   -> LoRA模型 (models/loras)"
    echo "  cv     -> Clip Vision (models/clip_vision)"
    echo "  vae    -> VAE模型 (models/vae)"
    echo "  cn     -> ControlNet (models/controlnet)"
    echo "  unet   -> UNET模型 (models/unet)"
    echo "----------------------------------------------------------------"
    echo "示例 (下载 Clip Vision):"
    echo "$0 https://huggingface.co/.../model.safetensors cv"
    echo "================================================================"
}

# 检查参数数量
if [ $# -ne 2 ]; then
    show_usage
    exit 1
fi

DOWNLOAD_URL=$1
INPUT_PARAM=$2
PROJECT_DIR="$(pwd)"

# --- 2. 核心逻辑：路径解析与智能修正 ---

# 将输入转换为小写，方便匹配
INPUT_LOWER=$(echo "$INPUT_PARAM" | tr '[:upper:]' '[:lower:]')

case "$INPUT_LOWER" in
    # --- 场景 A: 用户输入了正确的类型代码 (推荐) ---
    "ckpt" | "checkpoint" | "checkpoints" | "diffusion")
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
    "unet")
        TARGET_REL_PATH="models/unet"
        ;;
    "upscale" | "esrgan")
        TARGET_REL_PATH="models/upscale_models"
        ;;
    
    # --- 场景 B: 用户输入了自定义路径 (包含容错处理) ---
    *)
        # 错误检测：如果用户把文件名 (如 .safetensors) 也复制到了路径参数中
        if [[ "$INPUT_PARAM" == *".safetensors"* ]] || [[ "$INPUT_PARAM" == *".pth"* ]] || [[ "$INPUT_PARAM" == *".bin"* ]]; then
            echo "⚠️  检测到路径参数包含了文件名，正在自动修正..."
            # 使用 dirname 去掉文件名，只保留目录部分
            # 例如: models/clip_vision/file.safetensors -> models/clip_vision
            TARGET_REL_PATH=$(dirname "$INPUT_PARAM")
        else
            # 用户输入的是正常的自定义文件夹
            TARGET_REL_PATH="$INPUT_PARAM"
        fi
        ;;
esac

# --- 3. 构建与验证路径 ---

MODEL_SAVE_DIR="$PROJECT_DIR/$TARGET_REL_PATH"

# 安全检查：防止目标目录恰好是一个已存在的文件
if [ -f "$MODEL_SAVE_DIR" ]; then
    echo "❌ 错误: 目标路径 $MODEL_SAVE_DIR 是一个文件，无法创建为目录！"
    exit 1
fi

# 创建目录
if [ ! -d "$MODEL_SAVE_DIR" ]; then
    echo "📁 正在创建目录: $TARGET_REL_PATH"
    mkdir -p "$MODEL_SAVE_DIR"
fi

# --- 4. 执行下载 ---

FILE_NAME=$(basename "$DOWNLOAD_URL")
SAVE_PATH="$MODEL_SAVE_DIR/$FILE_NAME"

echo "----------------------------------------------------------------"
echo "任务确认:"
echo "🔗 来源: $DOWNLOAD_URL"
echo "📂 目标: $TARGET_REL_PATH/"
echo "📄 文件: $FILE_NAME"
echo "----------------------------------------------------------------"

# wget 参数说明：-c 断点续传, -P 指定目录 (虽然我们拼接了完整路径，但 -O 更稳妥)
wget --continue --progress=bar:force "$DOWNLOAD_URL" -O "$SAVE_PATH"

# --- 5. 结果校验 ---
if [ $? -eq 0 ]; then
    echo "✅ 下载成功！模型已就绪。"
    echo "📍 物理路径: $SAVE_PATH"
else
    echo "❌ 下载失败，请检查网络或链接有效性。"
    exit 1
fi