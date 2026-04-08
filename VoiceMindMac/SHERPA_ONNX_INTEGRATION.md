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

