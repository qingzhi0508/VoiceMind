#!/bin/bash

echo "=== VoiceMind 项目文件检查 ==="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 (缺失)"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
        return 0
    else
        echo -e "${RED}✗${NC} $1/ (缺失)"
        return 1
    fi
}

missing=0

echo "检查 SharedCore..."
check_file "SharedCore/Package.swift" || ((missing++))
check_file "SharedCore/Sources/SharedCore/SharedCore.swift" || ((missing++))
check_file "SharedCore/Sources/SharedCore/Protocol/MessageType.swift" || ((missing++))
check_file "SharedCore/Sources/SharedCore/Protocol/MessageEnvelope.swift" || ((missing++))
check_file "SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift" || ((missing++))
check_file "SharedCore/Sources/SharedCore/Security/HMACValidator.swift" || ((missing++))
check_file "SharedCore/Sources/SharedCore/Security/KeychainManager.swift" || ((missing++))
check_file "SharedCore/Sources/SharedCore/Models/PairingData.swift" || ((missing++))

echo ""
echo "检查 macOS 应用..."
check_file "VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/Network/WebSocketServer.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/Network/BonjourPublisher.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/Network/ConnectionManager.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/Hotkey/HotkeyMonitor.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/Hotkey/HotkeyConfiguration.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/TextInjection/TextInjector.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/Permissions/PermissionsManager.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/MenuBar/MenuBarController.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/MenuBar/MenuBarController+Delegates.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/MenuBar/PairingWindow.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/MenuBar/HotkeySettingsWindow.swift" || ((missing++))
check_file "VoiceMindMac/VoiceMindMac/MenuBar/PermissionsWindow.swift" || ((missing++))

echo ""
echo "检查 iOS 应用..."
check_file "VoiceMindiOS/VoiceMindiOS/VoiceMindiOSApp.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Network/BonjourBrowser.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Network/WebSocketClient.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Network/ReconnectionManager.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Network/ConnectionManager.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Network/DiscoveredService.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Network/PairingState.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Speech/SpeechController.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Speech/RecognitionState.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/ViewModels/ContentViewModel.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Views/ContentView.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Views/PairingView.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift" || ((missing++))
check_file "VoiceMindiOS/VoiceMindiOS/Info.plist" || ((missing++))

echo ""
echo "检查工作区和文档..."
check_file "VoiceMind.xcworkspace/contents.xcworkspacedata" || ((missing++))
check_file "README.md" || ((missing++))
check_file "TESTING_GUIDE.md" || ((missing++))

echo ""
echo "检查不应该存在的旧文件..."
if [ -f "VoiceMindiOS/VoiceMindiOS/ContentView.swift" ]; then
    echo -e "${RED}✗${NC} VoiceMindiOS/VoiceMindiOS/ContentView.swift (应该删除，使用 Views/ContentView.swift)"
    ((missing++))
else
    echo -e "${GREEN}✓${NC} 旧的 ContentView.swift 已删除"
fi

if [ -f "VoiceMindiOS/VoiceMindiOS/Persistence.swift" ]; then
    echo -e "${RED}✗${NC} VoiceMindiOS/VoiceMindiOS/Persistence.swift (应该删除)"
    ((missing++))
else
    echo -e "${GREEN}✓${NC} Persistence.swift 已删除"
fi

echo ""
echo "==================================="
if [ $missing -eq 0 ]; then
    echo -e "${GREEN}✓ 所有文件检查通过！${NC}"
    echo ""
    echo "下一步："
    echo "1. 在 Xcode 中打开 VoiceMind.xcworkspace"
    echo "2. 将新文件添加到对应的 target"
    echo "3. 按照 TESTING_GUIDE.md 进行测试"
    exit 0
else
    echo -e "${RED}✗ 发现 $missing 个问题${NC}"
    echo ""
    echo "请检查缺失的文件或删除不应该存在的文件"
    exit 1
fi
