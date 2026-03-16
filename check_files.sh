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
check_file "VoiceRelayMac/VoiceRelayMac/VoiceRelayMacApp.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/Network/WebSocketServer.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/Network/BonjourPublisher.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/Network/ConnectionManager.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/Hotkey/HotkeyMonitor.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/Hotkey/HotkeyConfiguration.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/TextInjection/TextInjector.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/Permissions/PermissionsManager.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/MenuBar/MenuBarController.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/MenuBar/MenuBarController+Delegates.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/MenuBar/PairingWindow.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/MenuBar/HotkeySettingsWindow.swift" || ((missing++))
check_file "VoiceRelayMac/VoiceRelayMac/MenuBar/PermissionsWindow.swift" || ((missing++))

echo ""
echo "检查 iOS 应用..."
check_file "VoiceRelayiOS/VoiceRelayiOS/VoiceRelayiOSApp.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Network/BonjourBrowser.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Network/WebSocketClient.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Network/ReconnectionManager.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Network/ConnectionManager.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Network/DiscoveredService.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Network/PairingState.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Speech/SpeechController.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Speech/RecognitionState.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/ViewModels/ContentViewModel.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Views/ContentView.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Views/PairingView.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Views/SettingsView.swift" || ((missing++))
check_file "VoiceRelayiOS/VoiceRelayiOS/Info.plist" || ((missing++))

echo ""
echo "检查工作区和文档..."
check_file "VoiceRelay.xcworkspace/contents.xcworkspacedata" || ((missing++))
check_file "README.md" || ((missing++))
check_file "TESTING_GUIDE.md" || ((missing++))

echo ""
echo "检查不应该存在的旧文件..."
if [ -f "VoiceRelayiOS/VoiceRelayiOS/ContentView.swift" ]; then
    echo -e "${RED}✗${NC} VoiceRelayiOS/VoiceRelayiOS/ContentView.swift (应该删除，使用 Views/ContentView.swift)"
    ((missing++))
else
    echo -e "${GREEN}✓${NC} 旧的 ContentView.swift 已删除"
fi

if [ -f "VoiceRelayiOS/VoiceRelayiOS/Persistence.swift" ]; then
    echo -e "${RED}✗${NC} VoiceRelayiOS/VoiceRelayiOS/Persistence.swift (应该删除)"
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
    echo "1. 在 Xcode 中打开 VoiceRelay.xcworkspace"
    echo "2. 将新文件添加到对应的 target"
    echo "3. 按照 TESTING_GUIDE.md 进行测试"
    exit 0
else
    echo -e "${RED}✗ 发现 $missing 个问题${NC}"
    echo ""
    echo "请检查缺失的文件或删除不应该存在的文件"
    exit 1
fi
