#!/bin/bash

echo "🔍 检查 iOS 扫码功能文件..."
echo ""

FILES=(
    "/Users/cayden/Data/my-data/voiceMind/VoiceRelayiOS/VoiceRelayiOS/Scanner/QRCodeScannerController.swift"
    "/Users/cayden/Data/my-data/voiceMind/VoiceRelayiOS/VoiceRelayiOS/Scanner/CameraPreview.swift"
    "/Users/cayden/Data/my-data/voiceMind/VoiceRelayiOS/VoiceRelayiOS/Views/QRCodeScannerView.swift"
)

all_exist=true
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $(basename $file)"
    else
        echo "❌ $(basename $file) (不存在)"
        all_exist=false
    fi
done

echo ""
echo "🔍 检查 ContentView 是否包含扫码按钮..."
if grep -q "扫码连接 Mac" "/Users/cayden/Data/my-data/voiceMind/VoiceRelayiOS/Views/ContentView.swift"; then
    echo "✅ ContentView 包含扫码按钮"
else
    echo "❌ ContentView 不包含扫码按钮"
    all_exist=false
fi

echo ""
echo "🔍 检查 Info.plist 相机权限..."
if grep -q "NSCameraUsageDescription" "/Users/cayden/Data/my-data/voiceMind/VoiceRelayiOS/VoiceRelayiOS/Info.plist"; then
    echo "✅ Info.plist 包含相机权限描述"
else
    echo "❌ Info.plist 缺少相机权限描述"
    all_exist=false
fi

echo ""
if [ "$all_exist" = true ]; then
    echo "✅ 所有文件检查通过！"
    echo ""
    echo "下一步："
    echo "1. 在 Xcode 中确认这些文件已添加到 VoiceRelayiOS target"
    echo "2. Clean Build Folder (Shift+Cmd+K)"
    echo "3. 重新构建并运行"
    echo "4. 使用真机测试（模拟器不支持相机）"
else
    echo "❌ 有文件缺失或配置错误，请检查上述问题"
fi
