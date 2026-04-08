#!/bin/bash
#==========================================
# Sherpa-ONNX 模型下载脚本
#==========================================
# 此脚本自动下载预训练的 Sherpa-ONNX ASR 模型
#
# 使用方法:
#   ./download-model.sh [模型名称]
#
# 可用模型:
#   whisper-tiny     - Whisper Tiny (英文, ~39MB, CPU)
#   whisper-small    - Whisper Small (英文, ~149MB, CPU)
#   whisper-base    - Whisper Base (英文, ~74MB, CPU)
#   whisper-medium  - Whisper Medium (多语言, ~1.5GB, CPU)
#   whisper-large   - Whisper Large (多语言, ~3GB, GPU推荐)
#   conformer-zh   - Conformer 中文 (~400MB, CPU)
#   paraformer-zh  - Paraformer 中文 (推荐, ~400MB, CPU)
#
# 默认: paraformer-zh (中文推荐)
#==========================================

set -e

# 配置
MODEL_DIR="${HOME}/Library/Application Support/VoiceMind/Models/SherpaOnnx"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 模型定义: 名称|URL|大小|语言
MODEL_WHISPER_TINY="whisper-tiny|https://huggingface.co/csukuangfj/sherpa-onnx-whisper-en/resolve/main/sherpa-onnx-whisper-tiny.en.tar.bz2|39MB|英文"
MODEL_WHISPER_SMALL="whisper-small|https://huggingface.co/csukuangfj/sherpa-onnx-whisper-en/resolve/main/sherpa-onnx-whisper-small.en.tar.bz2|149MB|英文"
MODEL_WHISPER_BASE="whisper-base|https://huggingface.co/csukuangfj/sherpa-onnx-whisper-en/resolve/main/sherpa-onnx-whisper-base.en.tar.bz2|74MB|英文"
MODEL_WHISPER_MEDIUM="whisper-medium|https://huggingface.co/csukuangfj/sherpa-onnx-whisper-ct2/resolve/main/sherpa-onnx-whisper-medium-ct2.tar.bz2|1.5GB|多语言"
MODEL_WHISPER_LARGE="whisper-large|https://huggingface.co/csukuangfj/sherpa-onnx-whisper-ct2/resolve/main/sherpa-onnx-whisper-large-ct2.tar.bz2|3GB|多语言"
MODEL_CONFORMER_ZH="conformer-zh|https://huggingface.co/csukuangfj/sherpa-onnx-conformer/resolve/main/sherpa-onnx-conformer-zh.tar.bz2|400MB|中文"
MODEL_PARAFORMER_ZH="paraformer-zh|https://huggingface.co/csukuangfj/sherpa-onnx-paraformer/resolve/main/sherpa-onnx-paraformer-zh.tar.bz2|400MB|中文"

# 默认模型
DEFAULT_MODEL="paraformer-zh"

# 解析参数
MODEL_NAME="${1:-$DEFAULT_MODEL}"

# 获取模型信息
get_model_info() {
    case "$1" in
        whisper-tiny)    echo "$MODEL_WHISPER_TINY" ;;
        whisper-small)   echo "$MODEL_WHISPER_SMALL" ;;
        whisper-base)    echo "$MODEL_WHISPER_BASE" ;;
        whisper-medium)  echo "$MODEL_WHISPER_MEDIUM" ;;
        whisper-large)   echo "$MODEL_WHISPER_LARGE" ;;
        conformer-zh)    echo "$MODEL_CONFORMER_ZH" ;;
        paraformer-zh)   echo "$MODEL_PARAFORMER_ZH" ;;
        *) echo "" ;;
    esac
}

MODEL_INFO=$(get_model_info "$MODEL_NAME")

# 检查模型是否有效
if [[ -z "$MODEL_INFO" ]]; then
    echo "❌ 未知模型: $MODEL_NAME"
    echo ""
    echo "可用模型:"
    echo "  whisper-tiny   - 英文 (~39MB)"
    echo "  whisper-small  - 英文 (~149MB)"
    echo "  whisper-base  - 英文 (~74MB)"
    echo "  whisper-medium- 多语言 (~1.5GB)"
    echo "  whisper-large - 多语言 (~3GB)"
    echo "  conformer-zh  - 中文 (~400MB)"
    echo "  paraformer-zh - 中文 (~400MB, 推荐)"
    exit 1
fi

# 解析模型信息
url=$(echo "$MODEL_INFO" | cut -d'|' -f2)
size=$(echo "$MODEL_INFO" | cut -d'|' -f3)
lang=$(echo "$MODEL_INFO" | cut -d'|' -f4)

echo "=========================================="
echo "Sherpa-ONNX 模型下载"
echo "=========================================="
echo ""
echo "模型: $MODEL_NAME"
echo "语言: $lang"
echo "大小: ~$size"
echo "URL: $url"
echo ""

# 创建目录
mkdir -p "$MODEL_DIR"
echo "📁 模型目录: $MODEL_DIR"

# 进入目录
cd "$MODEL_DIR"

# 检查是否已下载
if [[ -d "$MODEL_NAME" ]]; then
    echo "✅ 模型已存在: $MODEL_NAME"
    echo "   路径: $MODEL_DIR/$MODEL_NAME"
    echo ""
    echo "如需重新下载，请删除目录后重试:"
    echo "  rm -rf \"$MODEL_DIR/$MODEL_NAME\""
    exit 0
fi

# 下载模型
echo "📥 开始下载..."
echo "注意: 根据网络状况，可能需要几分钟到几十分钟"

filename="${url##*/}"

if command -v curl &> /dev/null; then
    curl -L -o "$filename" "$url" --progress-bar || {
        echo "❌ 下载失败"
        exit 1
    }
elif command -v wget &> /dev/null; then
    wget -O "$filename" "$url" --show-progress || {
        echo "❌ 下载失败"
        exit 1
    }
else
    echo "❌ 需要 curl 或 wget"
    exit 1
fi

# 解压
echo ""
echo "📦 解压中..."
mkdir -p "$MODEL_NAME"

if [[ "$filename" == *.bz2 ]]; then
    tar xjf "$filename" -C "$MODEL_NAME" --strip-components=1 || {
        echo "❌ 解压失败"
        exit 1
    }
elif [[ "$filename" == *.gz ]]; then
    tar xzf "$filename" -C "$MODEL_NAME" --strip-components=1 || {
        echo "❌ 解压失败"
        exit 1
    }
elif [[ "$filename" == *.zip ]]; then
    unzip -q "$filename" -d "$MODEL_NAME" || {
        echo "❌ 解压失败"
        exit 1
    }
fi

# 清理压缩包
rm -f "$filename"

# 创建配置文件
echo "📝 创建配置文件..."
cat > "$MODEL_NAME/model.config" << EOF
{
    "encoderPath": "$MODEL_DIR/$MODEL_NAME/encoder.onnx",
    "decoderPath": "$MODEL_DIR/$MODEL_NAME/decoder.onnx",
    "tokensPath": "$MODEL_DIR/$MODEL_NAME/tokens.txt",
    "language": "$([[ $MODEL_NAME == *-zh ]] && echo 'zh-CN' || echo 'en-US')"
}
EOF

echo ""
echo "=========================================="
echo "✅ 下载完成!"
echo "=========================================="
echo ""
echo "模型路径: $MODEL_DIR/$MODEL_NAME"
echo "语言: $lang"
echo ""
echo "配置文件: $MODEL_DIR/$MODEL_NAME/model.config"
echo ""

# 验证文件
if [[ -f "$MODEL_NAME/encoder.onnx" ]] && [[ -f "$MODEL_NAME/tokens.txt" ]]; then
    echo "✅ 模型文件验证通过"
else
    echo "⚠️ 模型文件验证失败，请检查下载"
fi
