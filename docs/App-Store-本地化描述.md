# App Store Connect 本地化描述文档

> 更新时间：2026-04-05
> 适用平台：iOS + macOS
> 支持语言：中文（zh-CN）、英文（en-US）

---

## 一、产品总览

| Product ID | 类型 | 显示名 (zh) | 显示名 (en) |
|-----------|------|------------|------------|
| `com.voicemind.twodevice.monthly` | 月度订阅 | 双端协同月度会员 | Two-Device Sync Monthly |
| `com.voicemind.twodevice.yearly` | 年度订阅 | 双端协同年度会员 | Two-Device Sync Yearly |
| `com.voicemind.twodevice.alllifetime` | 终身购买 | 双端协同终身版 | Two-Device Sync Lifetime |

---

## 二、中文（zh-CN）描述

### 2.1 双端协同月度会员

**显示名称：** 双端协同月度会员

**描述：**
解锁 iPhone 与 Mac 的无限次双端协同。免费用户每天最多可发起 50 次双端协同会话。

---

### 2.2 双端协同年度会员

**显示名称：** 双端协同年度会员

**描述：**
解锁 iPhone 与 Mac 的无限次双端协同，按年订阅更划算。免费用户每天最多可发起 50 次双端协同会话。

---

### 2.3 双端协同终身版

**显示名称：** 双端协同终身版

**描述：**
一次购买，永久解锁当前双端协同功能。终身版不包含未来新增高级功能。

---

## 三、英文（en-US）描述

### 3.1 Two-Device Sync Monthly

**Display Name:** Two-Device Sync Monthly

**Description:**
Unlock unlimited two-device sync between iPhone and Mac. Free users can start up to 50 sync sessions per day.

---

### 3.2 Two-Device Sync Yearly

**Display Name:** Two-Device Sync Yearly

**Description:**
Unlock unlimited two-device sync between iPhone and Mac with a better annual value. Free users can start up to 50 sync sessions per day.

---

### 3.3 Two-Device Sync Lifetime

**Display Name:** Two-Device Sync Lifetime

**Description:**
Unlock the current two-device sync feature permanently with a one-time purchase. Future premium features are not included.

---

## 四、App Store Connect 配置步骤

### 4.1 添加本地化版本

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 进入 **我的 App** → 选择 **VoiceMind**
3. 左侧菜单选择 **App Store** → 点击 **本地化版本** 旁边的 ➕ 按钮
4. 选择 **English** 添加英文本地化

### 4.2 填写各语言元数据

每个语言版本需要填写以下字段：

| 字段 | 中文 | 英文 |
|------|------|------|
| **显示名称** | 双端协同月度会员 | Two-Device Sync Monthly |
| **描述** | 见上方中文描述 | 见上方英文描述 |
| **关键词** | 语音输入,语音识别,打字,输入,效率,Mac,手机 | voice input,speech to text,dictation,typing,efficiency,Mac,phone |
| **隐私政策 URL** | https://voicemind.top-list.top/privacy.html | 同左 |

### 4.3 订阅价格

| 产品 | 价格 |
|------|------|
| 双端协同月度会员 | ¥22.00/月 |
| 双端协同年度会员 | ¥168.00/年 |
| 双端协同终身版 | ¥398.00（一次性） |

---

## 五、App Store 审核注意事项

1. **元数据中避免苹果品牌词**：描述中"iPhone 与 Mac"可保留，但 App 名称和副标题中不应单独出现"Mac"等词
2. **隐私政策必须有效**：上传前确认 `https://voicemind.top-list.top/privacy.html` 可访问
3. **订阅需要提供审核截图**：在 App Store Connect 的 **订阅显示名与定价** 页面填写本地化名称

---

## 六、产品 ID 汇总

| 产品 | Product ID | 类型 | 价格 |
|------|-----------|------|------|
| 双端协同月度会员 | `com.voicemind.twodevice.monthly` | Recurring (P1M) | ¥22/月 |
| 双端协同年度会员 | `com.voicemind.twodevice.yearly` | Recurring (P1Y) | ¥168/年 |
| 双端协同终身版 | `com.voicemind.twodevice.alllifetime` | Non-Consumable | ¥398 |

---

*文档位置：`/Users/cayden/Data/my-data/voicemind/docs/App-Store-本地化描述.md`*
