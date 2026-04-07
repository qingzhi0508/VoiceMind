#!/usr/bin/env python3
import os

base = "/Users/cayden/Data/my-data/voicemind/VoiceMindMac/VoiceMindMac/Resources"

# zh-Hans replacements: iPhone -> 手机, Mac -> 电脑
zh_subs = [
    ("与 iPhone 配对", "与手机配对"),
    ("在 iPhone 上输入此代码：", "在手机上输入此代码："),
    ("等待 iPhone 连接...", "等待手机连接..."),
    ("当前还没有和 iPhone 建立配对", "当前还没有和手机建立配对"),
    ("移除与 iPhone 的配对", "移除与手机的配对"),
    ("正在连接到 iPhone...", "正在连接到手机..."),
    ("未配对 - 请先与 iPhone 配对", "未配对 - 请先与手机配对"),
    ("在 iPhone 上打开", "在手机上打开"),
    ("在 iPhone 上输入配对码", "在手机上输入配对码"),
    ("在 iPhone 上按住麦克风说话，Mac 会自动转写", "在手机上按住麦克风说话，电脑会自动转写"),
    ("使用 iPhone 扫描此二维码", "使用手机扫描此二维码"),
    ("等待 iPhone 发起配对", "等待手机发起配对"),
    ("展示 iPhone 发来的数据，以及语音在 Mac 端转写后的最终文字", "展示手机发来的数据，以及语音在电脑端转写后的最终文字"),
    ("当 iPhone 发来配对请求、语音流或识别文本后", "当手机发来配对请求、语音流或识别文本后"),
    ("Mac 本地识别结果和 iPhone 同步文本", "本地识别结果和手机同步文本"),
    ("Mac 本地", "本地"),
    ("iPhone 同步", "手机同步"),
    ("通过设备进行语音识别，并在 Mac 应用内实时查看结果", "通过设备进行语音识别，并在电脑应用内实时查看结果"),
    ("确认 Mac 和 iPhone 连接在同一个局域网下", "确认电脑和手机连接在同一个局域网下"),
    ("在 Mac 中点击", "在电脑中点击"),
    ("转写结果会保留在 VoiceMind 的 Mac 窗口中", "转写结果会保留在 VoiceMind 的电脑窗口中"),
    ("把捕捉留给 iPhone，把查看、整理与推进交给 Mac", "把捕捉留给手机，把查看、整理与推进交给电脑"),
    ("需要时再连接 iPhone，让双端协同自然发生", "需要时再连接手机，让双端协同自然发生"),
    ("顺着 Mac 的节奏工作", "顺着电脑的节奏工作"),
    ("Mac 是 VoiceMind 的查看台，也是你推进内容的地方", "电脑是 VoiceMind 的查看台，也是你推进内容的地方"),
    ("Mac 端会发生什么", "电脑端会发生什么"),
    ("连接一次 iPhone 和 Mac，让语音工作流自然延续", "连接一次手机和电脑，让语音工作流自然延续"),
    ("iPhone 负责开口捕捉，Mac 负责展开查看，二者通过局域网保持同步", "手机负责开口捕捉，电脑负责展开查看，二者通过局域网保持同步"),
    ("iPhone", "手机"),
    ("确认 iPhone 和 Mac 在同一个局域网内，方便彼此发现", "确认手机和电脑在同一个局域网内，方便彼此发现"),
    ("从 Mac 发起配对", "从电脑发起配对"),
    ("VoiceMind 会在 Mac 上显示二维码和配对码，等待 iPhone 接入", "VoiceMind 会在电脑上显示二维码和配对码，等待手机接入"),
    ("在 iPhone 上确认连接", "在手机上确认连接"),
    ("启动 Mac 端 VoiceMind", "启动电脑端 VoiceMind"),
    ("iPhone 负责采集，Mac 负责查看", "手机负责采集，电脑负责查看"),
    ("先在这台 Mac 上启动 VoiceMind 服务", "先在这台电脑上启动 VoiceMind 服务"),
    ("VoiceMind 服务已经在这台 Mac 上运行", "VoiceMind 服务已经在这台电脑上运行"),
    ("准备好后，在 iPhone 上打开 VoiceMind 并进入配对界面", "准备好后，在手机上打开 VoiceMind 并进入配对界面"),
    ("完成连接后，在 iPhone 开口说话，在 Mac 继续查看与整理", "完成连接后，在手机上开口说话，在电脑继续查看与整理"),
    ("免费用户可从 iPhone 每天发起最多 50 次双端协同。你可以在 iPhone 和 Mac 上解锁无限次", "免费用户可从手机每天发起最多 50 次双端协同。你可以在手机和电脑上解锁无限次"),
    ("你的月度方案已在 iPhone 和 Mac 上解锁无限次双端协同", "你的月度方案已在手机和电脑上解锁无限次双端协同"),
    ("你的年度方案已在 iPhone 和 Mac 上解锁无限次双端协同", "你的年度方案已在手机和电脑上解锁无限次双端协同"),
    ("你的终身购买已在 iPhone 和 Mac 上永久解锁当前双端协同功能", "你的终身购买已在手机和电脑上永久解锁当前双端协同功能"),
    ("查询最近 30 天的语音识别文本，包含 Mac 本地和 iPhone 同步结果", "查询最近 30 天的语音识别文本，包含本地和手机同步结果"),
    ("Mac 正在等待与 iPhone 建立连接", "电脑正在等待与手机建立连接"),
    ("iPhone 与 Mac 已建立可用连接", "手机与电脑已建立可用连接"),
    ("已生成配对码，等待 iPhone 扫描二维码或输入配对码", "已生成配对码，等待手机扫描二维码或输入配对码"),
    ("配对信息已保存，正在向 iPhone 返回成功结果", "配对信息已保存，正在向手机返回成功结果"),
]

# en replacements: iPhone -> phone, Mac -> desktop
en_subs = [
    ("Your Mac is not paired with an iPhone yet", "Your desktop is not paired with a phone yet"),
    ("Your Mac is paired with", "Your desktop is paired with"),
    ("Browse the last 30 days of voice transcripts from local Mac capture and synced iPhone text", "Browse the last 30 days of voice transcripts from local capture and synced phone text"),
    ("Pair with iPhone", "Pair with Phone"),
    ("Enter this code on your iPhone:", "Enter this code on your phone:"),
    ("Waiting for iPhone to connect...", "Waiting for phone to connect..."),
    ("This will remove the pairing with your iPhone", "This will remove the pairing with your phone"),
    ("Connecting to iPhone...", "Connecting to phone..."),
    ("Not paired - Pair with your iPhone first", "Not paired - Pair with your phone first"),
    ("Open %@ on your iPhone", "Open %@ on your phone"),
    ("Enter the pairing code on your iPhone", "Enter the pairing code on your phone"),
    ("After pairing, hold the mic on your iPhone to speak. The Mac will transcribe", "After pairing, hold the mic on your phone to speak. The desktop will transcribe"),
    ("Scan this QR code with your iPhone", "Scan this QR code with your phone"),
    ("Waiting for iPhone to start pairing", "Waiting for phone to start pairing"),
    ("Shows data from iPhone and the final transcribed text on Mac", "Shows data from phone and the final transcribed text on desktop"),
    ("Records will appear here after the iPhone sends", "Records will appear here after the phone sends"),
    ("Final Mac transcripts and synced iPhone text", "Final desktop transcripts and synced phone text"),
    ("Mac Local", "Local"),
    ("iPhone Sync", "Phone Sync"),
    ("Use your iOS device for speech recognition and review results inside the Mac app", "Use your iOS device for speech recognition and review results inside the desktop app"),
    ("Make sure your Mac and iPhone are connected", "Make sure your desktop and phone are connected"),
    ('Click "Start Pairing" on the Mac', 'Click "Start Pairing" on the desktop'),
    ("VoiceMind for Mac gives your voice a focused desktop space", "VoiceMind for desktop gives your voice a focused desktop space"),
    ("Pair with iPhone when you want capture and desktop review to move as one", "Pair with phone when you want capture and desktop review to move as one"),
    ("Made for your Mac flow", "Made for your desktop flow"),
    ("Your Mac becomes the place where voice turns into work", "Your desktop becomes the place where voice turns into work"),
    ("Pair iPhone and Mac once", "Pair phone and desktop once"),
    ("Start on iPhone, keep the desktop view on Mac", "Start on phone, keep the desktop view on desktop"),
    ("Make sure iPhone and Mac can see each other", "Make sure phone and desktop can see each other"),
    ("VoiceMind will show a QR code and pairing code for your iPhone", "VoiceMind will show a QR code and pairing code for your phone"),
    ("Confirm on iPhone", "Confirm on phone"),
    ("Turn on VoiceMind for Mac", "Turn on VoiceMind for desktop"),
    ("Capture on iPhone, review on Mac", "Capture on phone, review on desktop"),
    ("Open VoiceMind on iPhone and enter the pairing flow", "Open VoiceMind on phone and enter the pairing flow"),
    ("Once connected, speak on iPhone and keep reviewing the transcript on Mac", "Once connected, speak on phone and keep reviewing the transcript on desktop"),
    ("Free users can start up to 50 sync sessions per day from iPhone. Upgrade here to unlock unlimited sync on both devices", "Free users can start up to 50 sync sessions per day from phone. Upgrade here to unlock unlimited sync on both devices"),
    ("Your monthly plan unlocks unlimited two-device sync on iPhone and Mac", "Your monthly plan unlocks unlimited two-device sync on phone and desktop"),
    ("Your yearly plan unlocks unlimited two-device sync on iPhone and Mac", "Your yearly plan unlocks unlimited two-device sync on phone and desktop"),
    ("Your lifetime purchase unlocks the current two-device sync feature on iPhone and Mac", "Your lifetime purchase unlocks the current two-device sync feature on phone and desktop"),
    ("VoiceMind Mac", "VoiceMind Desktop"),
]

# zh-Hant replacements: iPhone -> 手機, Mac -> 電腦
zh_hant_subs = [
    ("与 iPhone 配对", "與手機配對"),
    ("在 iPhone 上輸入此代碼：", "在手機上輸入此代碼："),
    ("等待 iPhone 連接...", "等待手機連接..."),
    ("當前還沒有和 iPhone 建立配對", "當前還沒有和手機建立配對"),
    ("移除與 iPhone 的配對", "移除與手機的配對"),
    ("正在連接到 iPhone...", "正在連接到手機..."),
    ("未配對 - 請先與 iPhone 配對", "未配對 - 請先與手機配對"),
    ("在 iPhone 上打開", "在手機上打開"),
    ("在 iPhone 上輸入配對碼", "在手機上輸入配對碼"),
    ("在 iPhone 上按住麥克風說話，Mac 會自動轉寫", "在手機上按住麥克風說話，電腦會自動轉寫"),
    ("使用 iPhone 掃描此二維碼", "使用手機掃描此二維碼"),
    ("等待 iPhone 發起配對", "等待手機發起配對"),
    ("展示 iPhone 發來的數據，以及語音在 Mac 端轉寫後的最終文字", "展示手機發來的數據，以及語音在電腦端轉寫後的最終文字"),
    ("當 iPhone 發來配對請求、語音流或識別文本後", "當手機發來配對請求、語音流或識別文本後"),
    ("Mac 本機識別結果與 iPhone 同步文字", "本機識別結果與手機同步文字"),
    ("Mac 本機", "本機"),
    ("iPhone 同步", "手機同步"),
    ("通過設備進行語音識別，並在 Mac 應用內即時查看結果", "通過設備進行語音識別，並在電腦應用內即時查看結果"),
    ("確認 Mac 和 iPhone 連接在同一個區域網路下", "確認電腦和手機連接在同一個區域網路下"),
    ("在 Mac 中點擊", "在電腦中點擊"),
    ("轉寫結果會保留在 VoiceMind 的 Mac 視窗中", "轉寫結果會保留在 VoiceMind 的電腦視窗中"),
    ("把捕捉交給 iPhone，把查看、整理與推進交給 Mac", "把捕捉交給手機，把查看、整理與推進交給電腦"),
    ("需要時再連接 iPhone，讓雙端協同自然發生", "需要時再連接手機，讓雙端協同自然發生"),
    ("順著 Mac 的節奏工作", "順著電腦的節奏工作"),
    ("Mac 是 VoiceMind 的查看台，也是你推進內容的地方", "電腦是 VoiceMind 的查看台，也是你推進內容的地方"),
    ("Mac 端會發生什麼", "電腦端會發生什麼"),
    ("連接一次 iPhone 和 Mac，讓語音工作流自然延續", "連接一次手機和電腦，讓語音工作流自然延續"),
    ("iPhone 負責開口捕捉，Mac 負責展開查看，兩者透過區域網路保持同步", "手機負責開口捕捉，電腦負責展開查看，兩者透過區域網路保持同步"),
    ("iPhone", "手機"),
    ("確認 iPhone 和 Mac 在同一個區域網路內，方便彼此發現", "確認手機和電腦在同一個區域網路內，方便彼此發現"),
    ("從 Mac 發起配對", "從電腦發起配對"),
    ("VoiceMind 會在 Mac 上顯示 QR Code 和配對碼，等待 iPhone 接入", "VoiceMind 會在電腦上顯示 QR Code 和配對碼，等待手機接入"),
    ("在 iPhone 上確認連接", "在手機上確認連接"),
    ("啟動 Mac 端 VoiceMind", "啟動電腦端 VoiceMind"),
    ("iPhone 負責採集，Mac 負責查看", "手機負責採集，電腦負責查看"),
    ("先在這台 Mac 上啟動 VoiceMind 服務", "先在這台電腦上啟動 VoiceMind 服務"),
    ("VoiceMind 服務已經在這台 Mac 上執行", "VoiceMind 服務已經在這台電腦上執行"),
    ("準備好後，在 iPhone 上開啟 VoiceMind 並進入配對畫面", "準備好後，在手機上開啟 VoiceMind 並進入配對畫面"),
    ("完成連接後，在 iPhone 開口說話，在 Mac 繼續查看與整理", "完成連接後，在手機上開口說話，在電腦繼續查看與整理"),
    ("免費用戶可從 iPhone 每天發起最多 50 次雙端協同。你可以在 iPhone 和 Mac 上解鎖無限次", "免費用戶可從手機每天發起最多 50 次雙端協同。你可以在手機和電腦上解鎖無限次"),
    ("你的月度方案已在 iPhone 和 Mac 上解鎖無限次雙端協同", "你的月度方案已在手機和電腦上解鎖無限次雙端協同"),
    ("你的年度方案已在 iPhone 和 Mac 上解鎖無限次雙端協同", "你的年度方案已在手機和電腦上解鎖無限次雙端協同"),
    ("你的終身購買已在 iPhone 和 Mac 上永久解鎖目前的雙端協同功能", "你的終身購買已在手機和電腦上永久解鎖目前的雙端協同功能"),
    ("查詢最近 30 天的語音識別文字，包含 Mac 本機與 iPhone 同步結果", "查詢最近 30 天的語音識別文字，包含本機與手機同步結果"),
    ("Mac 正在等待與 iPhone 建立連接", "電腦正在等待與手機建立連接"),
    ("iPhone 與 Mac 已建立可用連接", "手機與電腦已建立可用連接"),
    ("已生成配對碼，等待 iPhone 掃描二維碼或輸入配對碼", "已生成配對碼，等待手機掃描二維碼或輸入配對碼"),
    ("配對信息已保存，正在向 iPhone 返回成功結果", "配對信息已保存，正在向手機返回成功結果"),
]

files = {
    f"{base}/zh-Hans.lproj/Localizable.strings": zh_subs,
    f"{base}/en.lproj/Localizable.strings": en_subs,
    f"{base}/zh-Hant.lproj/Localizable.strings": zh_hant_subs,
}

total = 0
for filepath, subs in files.items():
    if not os.path.exists(filepath):
        print(f"Skip (not found): {filepath}")
        continue
    with open(filepath, "r") as f:
        content = f.read()
    for old, new in subs:
        content = content.replace(old, new)
    with open(filepath, "w") as f:
        f.write(content)
    print(f"Done: {os.path.basename(filepath)} ({len(subs)} replacements)")
    total += len(subs)

print(f"All done! Total: {total} replacements")
