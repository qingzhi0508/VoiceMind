#!/bin/bash
#==========================================
# Sherpa-ONNX 一键安装脚本
#==========================================
# 自动完成所有设置步骤
#
# 使用方法:
#   ./setup-sherpa-onnx.sh [模型名]
#
# 示例:
#   ./setup-sherpa-onnx.sh           # 下载中文模型 (paraformer-zh)
#   ./setup-sherpa-onnx.sh whisper-large  # 下载大型 Whisper 模型
#==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Sherpa-ONNX 一键安装"
echo "=========================================="
echo ""

#--------------------------------
# 步骤 1: 检查环境
#--------------------------------
echo "📋 步骤 1: 检查环境..."

# 检查 macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ 此脚本仅支持 macOS"
    exit 1
fi
echo "  ✅ macOS 环境"

# 检查 Xcode
if ! command -v xcode-select &> /dev/null; then
    echo "❌ Xcode 未安装"
    exit 1
fi
echo "  ✅ Xcode 已安装"

# 检查 CMake
if ! command -v cmake &> /dev/null; then
    echo ""
    echo "⚠️ CMake 未安装，正在安装..."
    if command -v brew &> /dev/null; then
        brew install cmake
    else
        echo "❌ Homebrew 未安装，请先安装: https://brew.sh"
        exit 1
    fi
fi
echo "  ✅ CMake 已安装"

#--------------------------------
# 步骤 2: 构建 Sherpa-ONNX
#--------------------------------
echo ""
echo "📋 步骤 2: 构建 Sherpa-ONNX..."

BUILD_DIR="$SCRIPT_DIR/../build-sherpa-onnx"
if [[ -d "$BUILD_DIR" ]] && [[ -f "$BUILD_DIR/lib/libsherpa-onnx.a" ]]; then
    echo "  ✅ 构建已完成，跳过构建步骤"
    SKIP_BUILD=1
else
    echo "  ⚠️ 需要构建 Sherpa-ONNX（预计 15-30 分钟）"
    echo "  💡 构建完成后会自动跳过此步骤"
    SKIP_BUILD=0
fi

if [[ $SKIP_BUILD == 0 ]]; then
    echo ""
    echo "开始构建 Sherpa-ONNX..."
    echo "这是首次构建，可能需要 15-30 分钟"
    echo ""

    if [[ -f "./build-sherpa-onnx.sh" ]]; then
        chmod +x ./build-sherpa-onnx.sh

        # 检测是否支持 Metal
        if [[ "$(uname -m)" == "arm64" ]]; then
            echo "检测到 Apple Silicon，将启用 Metal 加速..."
            ./build-sherpa-onnx.sh --with-metal
        else
            ./build-sherpa-onnx.sh
        fi
    else
        echo "❌ 构建脚本不存在: build-sherpa-onnx.sh"
        echo "请确保脚本位于: $SCRIPT_DIR/build-sherpa-onnx.sh"
        exit 1
    fi
fi

#--------------------------------
# 步骤 3: 下载模型
#--------------------------------
echo ""
echo "📋 步骤 3: 下载 ASR 模型..."

MODEL_NAME="${1:-paraformer-zh}"

if [[ -f "./download-model.sh" ]]; then
    chmod +x ./download-model.sh
    ./download-model.sh "$MODEL_NAME"
else
    echo "❌ 模型下载脚本不存在"
    exit 1
fi

#--------------------------------
# 步骤 4: 集成到 Xcode
#--------------------------------
echo ""
echo "📋 步骤 4: 集成到 Xcode..."
echo ""
echo "⚠️ 以下步骤需要手动完成:"
echo ""
echo "1. 打开 Xcode 项目:"
echo "   open $SCRIPT_DIR/../VoiceMindMac.xcodeproj"
echo ""
echo "2. 添加 XCFramework:"
echo "   - 在项目导航器中，右键点击 VoiceMindMac"
echo "   - 选择 'Add Files to \"VoiceMindMac\"'"
echo "   - 选择 'build-sherpa-onnx/XCFramework' 目录"
echo "   - 确保 'Copy items if needed' 已勾选"
echo ""
echo "3. 添加 Bridging Header:"
echo "   - 创建新文件: VoiceMindMac-Bridging-Header.h"
echo "   - 内容:"
echo '     #ifndef VoiceMindMac_Bridging_Header_h'
echo '     #define VoiceMindMac_Bridging_Header_h'
echo '     #include <sherpa-onnx/c-api/c-api.h>'
echo '     #endif'
echo ""
echo "4. 配置 Build Settings:"
echo "   - Swift Compiler → Bridging Header: \$(SRCROOT)/VoiceMindMac/VoiceMindMac-Bridging-Header.h"
echo "   - Header Search Paths: \$(SRCROOT)/build-sherpa-onnx/include"
echo "   - Library Search Paths: \$(SRCROOT)/build-sherpa-onnx/lib"
echo ""
echo "5. 设置链接库:"
echo "   - 在 Build Phases → Link Binary With Libraries 中添加:"
echo "   - libsherpa-onnx.a"
echo "   - libonnxruntime.a"
echo ""
echo "6. 重新构建项目"
echo ""

#--------------------------------
# 完成
#--------------------------------
echo "=========================================="
echo "✅ 安装向导完成!"
echo "=========================================="
echo ""
echo "请按照上述步骤完成 Xcode 配置后，重新构建项目。"
echo ""
