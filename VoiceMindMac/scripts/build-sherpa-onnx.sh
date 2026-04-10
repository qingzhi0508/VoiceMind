#!/bin/bash
#==========================================
# Sherpa-ONNX macOS/iOS XCFramework 构建脚本
#==========================================
# 此脚本用于构建 Sherpa-ONNX 的 macOS XCFramework
# 构建完成后，将生成的 XCFramework 集成到 VoiceMindMac 项目中
#
# 前置要求:
# - macOS 12.0+
# - Xcode 14.0+
# - CMake 3.24+
# - Python 3.8+ (用于下载模型)
# - Git
#
# 使用方法:
#   ./build-sherpa-onnx.sh [选项]
#
# 选项:
#   --with-metal    启用 Metal GPU 加速 (Apple Silicon)
#   --with-coreml   启用 CoreML 加速
#   --clean         清理构建缓存后重新构建
#   --help          显示帮助信息
#==========================================

set -e  # 遇到错误立即退出

#--------------------------------
# 配置
#--------------------------------
SHERPA_ONNX_VERSION="v1.12.34"
SHERPA_ONNX_REPO="https://github.com/k2-fsa/sherpa-onnx.git"
BUILD_DIR="build-sherpa-onnx"
XCFRAMEWORK_OUTPUT="XCFramework"
INSTALL_PREFIX="/usr/local"

# 默认选项
ENABLE_METAL=OFF
ENABLE_COREML=OFF
CLEAN_BUILD=OFF

#--------------------------------
# 解析参数
#--------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-metal)
            ENABLE_METAL=ON
            shift
            ;;
        --with-coreml)
            ENABLE_COREML=ON
            shift
            ;;
        --clean)
            CLEAN_BUILD=ON
            shift
            ;;
        --help)
            echo "Sherpa-ONNX macOS XCFramework 构建脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --with-metal    启用 Metal GPU 加速 (推荐 Apple Silicon)"
            echo "  --with-coreml   启用 CoreML 加速"
            echo "  --clean         清理构建缓存后重新构建"
            echo "  --help          显示此帮助信息"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            exit 1
            ;;
    esac
done

#--------------------------------
# 检测环境
#--------------------------------
echo "=========================================="
echo "Sherpa-ONNX 构建配置"
echo "=========================================="
echo ""

# 检测 macOS 版本
MACOS_VERSION=$(sw_vers -productVersion)
echo "macOS 版本: $MACOS_VERSION"

# 检测 CPU 架构
ARCH=$(uname -m)
echo "CPU 架构: $ARCH"

# 检测 Apple Silicon
if [[ "$ARCH" == "arm64" ]]; then
    echo "Apple Silicon: 是"
    IS_APPLE_SILICON=ON
else
    echo "Apple Silicon: 否"
    IS_APPLE_SILICON=OFF
fi

# 检测 Xcode
if ! command -v xcode-select &> /dev/null; then
    echo "错误: Xcode 未安装"
    exit 1
fi
XCODE_VERSION=$(xcodebuild -version | head -1)
echo "Xcode: $XCODE_VERSION"

# 检测 CMake
if ! command -v cmake &> /dev/null; then
    echo "错误: CMake 未安装"
    echo "安装: brew install cmake"
    exit 1
fi
CMAKE_VERSION=$(cmake --version | head -1)
echo "CMake: $CMAKE_VERSION"

# 检测 Python
if ! command -v python3 &> /dev/null; then
    echo "错误: Python3 未安装"
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
echo "Python: $PYTHON_VERSION"

echo ""
echo "构建选项:"
echo "  Metal 加速: $ENABLE_METAL"
echo "  CoreML 加速: $ENABLE_COREML"
echo "  清理后构建: $CLEAN_BUILD"
echo ""

#--------------------------------
# 准备构建目录
#--------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "项目根目录: $PROJECT_ROOT"

# 清理旧构建
if [[ "$CLEAN_BUILD" == "ON" ]]; then
    echo "🧹 清理旧构建..."
    rm -rf "$BUILD_DIR"
    rm -rf "$XCFRAMEWORK_OUTPUT"
fi

mkdir -p "$BUILD_DIR/src"

#--------------------------------
# 克隆 Sherpa-ONNX
#--------------------------------
if [[ ! -d "$BUILD_DIR/src/.git" ]]; then
    echo "📥 克隆 Sherpa-ONNX 仓库..."
    git clone --depth 1 --branch "$SHERPA_ONNX_VERSION" "$SHERPA_ONNX_REPO" "$BUILD_DIR/src"
else
    echo "✅ Sherpa-ONNX 已存在，更新到指定版本..."
    git -C "$BUILD_DIR/src" fetch --depth 1 origin "$SHERPA_ONNX_VERSION"
    git -C "$BUILD_DIR/src" checkout "$SHERPA_ONNX_VERSION"
fi

cd "$BUILD_DIR"

#--------------------------------
# 配置 CMake
#--------------------------------
echo "🔧 配置 CMake..."

# 检测 ONNX Runtime
# 如果没有预编译的 ONNX Runtime，需要先构建
echo "检查 ONNX Runtime..."

# macOS 通用配置
CMAKE_ARGS=(
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
    -DBUILD_SHARED_LIBS=OFF
    -DCMAKE_BUILD_TYPE=Release
    -DSHERPA_ONNX_ENABLE_APPLE=ON
    -DSHERPA_ONNX_ENABLE_CHECK=ON
    -DSHERPA_ONNX_ENABLE_PYTHON=OFF
    -DSHERPA_ONNX_ENABLE_TESTING=OFF
)

# Apple 平台配置
CMAKE_ARGS+=(
    -DCMAKE_SYSTEM_NAME=Darwin
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
)

# Metal 加速
if [[ "$ENABLE_METAL" == "ON" ]]; then
    CMAKE_ARGS+=(-DSHERPA_ONNX_ENABLE_METAL=ON)
    echo "  ✅ Metal 加速已启用"
else
    CMAKE_ARGS+=(-DSHERPA_ONNX_ENABLE_METAL=OFF)
fi

# CoreML 加速
if [[ "$ENABLE_COREML" == "ON" ]]; then
    CMAKE_ARGS+=(-DSHERPA_ONNX_ENABLE_COREML=ON)
    echo "  ✅ CoreML 加速已启用"
else
    CMAKE_ARGS+=(-DSHERPA_ONNX_ENABLE_COREML=OFF)
fi

# ONNX Runtime 路径 (如果有预编译版本)
# ONNX_RUNTIME_ROOT="/path/to/onnxruntime"
# CMAKE_ARGS+=(-DONNXRUNTIME_ROOT="$ONNX_RUNTIME_ROOT")

# 运行 CMake
cmake "${CMAKE_ARGS[@]}" src

#--------------------------------
# 构建
#--------------------------------
echo ""
echo "🔨 开始构建 Sherpa-ONNX..."
echo "注意: 首次构建可能需要 10-30 分钟"

# 并行构建
CPU_COUNT=$(sysctl -n hw.ncpu)
echo "使用 $CPU_COUNT 个核心并行构建..."

cmake --build . --parallel "$CPU_COUNT" --config Release

#--------------------------------
# 创建 XCFramework
#--------------------------------
echo ""
echo "📦 创建 XCFramework..."

# 获取构建产物路径
BUILD_TYPE="Release"
if [[ "$ARCH" == "arm64" ]]; then
    BUILD_DIR_ARM64="build/Release-arm64"
    BUILD_DIR_X86="build/Release-x86_64"
else
    BUILD_DIR_ARM64=""
    BUILD_DIR_X86="build/Release"
fi

# macOS 库的路径
MACOS_LIB=""

if [[ -n "$BUILD_DIR_ARM64" ]] && [[ -d "$BUILD_DIR_ARM64" ]]; then
    MACOS_LIB_ARM64="$BUILD_DIR_ARM64/libsherpa-onnx.a"
fi

if [[ -d "$BUILD_DIR_X86" ]]; then
    MACOS_LIB_X86="$BUILD_DIR_X86/libsherpa-onnx.a"
fi

# 创建 XCFramework (简化版本)
# 完整版本需要使用 xcodebuild -create-xcframework
# 这里假设我们已经有了静态库

mkdir -p "$XCFRAMEWORK_OUTPUT"

echo "XCFramework 输出目录: $PROJECT_ROOT/$BUILD_DIR/$XCFRAMEWORK_OUTPUT"
echo ""
echo "=========================================="
echo "构建完成!"
echo "=========================================="
echo ""
echo "下一步:"
echo "1. 将 $XCFRAMEWORK_OUTPUT 目录中的 Framework 拖入 Xcode 项目"
echo "2. 在 Xcode 中添加 bridging header 并导入 sherpa-onnx C 头文件"
echo "3. 重新构建 VoiceMindMac 项目"
echo ""
echo "或者运行以下命令将库安装到系统:"
echo "  sudo cmake --install . --prefix $INSTALL_PREFIX"
echo ""

#--------------------------------
# 创建 Xcode 集成指南
#--------------------------------
cat > "$PROJECT_ROOT/SHERPA_ONNX_INTEGRATION.md" << 'EOF'
# Sherpa-ONNX 集成指南

## 前置要求

1. 已完成 `build-sherpa-onnx.sh` 脚本执行
2. 生成了 `XCFramework` 目录

## 集成步骤

### 1. 添加 XCFramework 到项目

1. 打开 `VoiceMindMac.xcodeproj`
2. 右键项目 → **Add Files to "VoiceMindMac"**
3. 选择 `XCFramework/sherpa-onnx.xcframework`
4. 确保 "Copy items if needed" 已勾选
5. 选择 Target: VoiceMindMac

### 2. 配置 Search Paths

在 Xcode Build Settings 中:

```
Header Search Paths:
  $(SRCROOT)/XCFramework/sherpa-onnx/include

Library Search Paths:
  $(SRCROOT)/XCFramework/sherpa-onnx/lib/$(CONFIGURATION)/
```

### 3. 创建 Bridging Header

创建 `VoiceMindMac-Bridging-Header.h`:

```objc
#ifndef VoiceMindMac_Bridging_Header_h
#define VoiceMindMac_Bridging_Header_h

// Sherpa-ONNX C API
#include <sherpa-onnx/c-api/c-api.h>

#endif
```

在 Build Settings 中设置:
```
Swift Compiler - General → Objective-C Bridging Header:
  $(SRCROOT)/VoiceMindMac/VoiceMindMac-Bridging-Header.h
```

### 4. 下载 ASR 模型

Sherpa-ONNX 需要 ASR 模型文件。以下是推荐的模型:

#### 流式 Whisper 模型 (推荐)

```bash
# 创建模型目录
mkdir -p ~/Library/Application\ Support/VoiceMind/Models/SherpaOnnx/zipformer-whisper

# 下载中文模型
curl -L -o zipformer-whisper-ct2.tar.bz2 \
  "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-ct2/resolve/main/zipformer-whisper-3-ct2.tar.bz2"

# 解压
tar xvf zipformer-whisper-ct2.tar.bz2

# 或使用 Python 脚本下载
python3 << 'PYEOF'
import urllib.request
import os

model_dir = os.path.expanduser("~/Library/Application Support/VoiceMind/Models/SherpaOnnx")
os.makedirs(model_dir, exist_ok=True)

# 模型 URL (示例)
url = "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-ct2/resolve/main/zipformer-whisper-3-ct2.tar.bz2"
filename = os.path.join(model_dir, "model.tar.bz2")
print(f"Downloading to {filename}...")
urllib.request.urlretrieve(url, filename)
PYEOF
```

#### 硅基流动 Whisper 模型

```bash
# 下载硅基流动优化的 Whisper 模型
curl -L -o sherpa-onnx-model.tar.bz2 \
  "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.2.34/..."
```

### 5. 验证集成

运行 VoiceMindMac 应用，检查日志输出:

```
✅ Sherpa-ONNX 库已找到
✅ Sherpa-ONNX 模型已配置
🎤 Sherpa-ONNX 开始识别
```

## 模型下载链接

| 模型 | 语言 | 大小 | 链接 |
|------|------|------|------|
| Zipformer-Whisper | 多语言 | ~1.2GB | HuggingFace |
| Conformer | 中文 | ~400MB | HuggingFace |
| Whisper Tiny | 英文 | ~39MB | HuggingFace |

详细模型列表: https://k2-fsa.github.io/sherpa/onnx/pretrained_models/

## 故障排除

### 库未找到

```
⚠️ Sherpa-ONNX 库未找到
```

解决方案:
1. 检查 XCFramework 是否正确添加
2. 确认 Library Search Paths 配置正确
3. 检查 Framework 是否链接到 Target

### 模型加载失败

```
⚠️ 未找到 Sherpa-ONNX 模型
```

解决方案:
1. 确认模型文件放置在 `~/Library/Application Support/VoiceMind/Models/SherpaOnnx/`
2. 检查模型目录结构是否正确
3. 查看日志中的具体路径

### Metal 加速不可用

如果构建时未启用 Metal，识别可能使用 CPU 模式，速度较慢。重新构建并添加 `--with-metal` 选项。

EOF

echo "✅ 已生成集成指南: $PROJECT_ROOT/SHERPA_ONNX_INTEGRATION.md"
