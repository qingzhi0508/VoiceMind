# FTP/SFTP 安全组配置指南

## 📋 概述

FTP和SFTP是两种不同的文件传输协议：

- **FTP**（File Transfer Protocol）：传统协议，不加密，端口21
- **SFTP**（SSH File Transfer Protocol）：基于SSH加密，安全，推荐使用

---

## 第一部分：云服务器安全组配置

### 阿里云服务器

#### 步骤 1：登录阿里云控制台

访问 https://ecs.console.aliyun.com

#### 步骤 2：找到安全组

1. 进入 "云服务器 ECS" → "实例"
2. 点击你的实例名称
3. 在 "本实例安全组" 中点击 "管理"
4. 点击 "安全组规则" → "入方向" / "出方向"

#### 步骤 3：添加SFTP安全规则

**入方向规则（允许访问）：**

| 协议 | 端口范围 | 授权对象 | 说明 |
|------|---------|---------|------|
| TCP | 22/22 | 0.0.0.0/0 | SSH/SFTP访问（测试用） |
| TCP | 22/22 | 你的IP/32 | SSH/SFTP访问（生产用，更安全） |

**建议：**
- 生产环境建议只开放你的IP地址
- 可以临时开放 0.0.0.0/0 用于测试，之后修改

#### 步骤 4：限制IP访问（推荐）

为了安全，建议只允许特定IP访问：

1. 将 "授权对象" 从 `0.0.0.0/0` 改为你的固定IP地址
2. 如果你使用动态IP，可以改为 `你的IP/24` 或 `你的IP/16`

**查找你的公网IP：**
```bash
curl ifconfig.me
# 或
curl ipinfo.io/ip
```

---

### 腾讯云服务器

#### 步骤 1：登录腾讯云控制台

访问 https://console.cloud.tencent.com

#### 步骤 2：配置安全组

1. 进入 "云服务器" → "安全组"
2. 选择你的安全组
3. 点击 "入站规则" / "出站规则"

#### 步骤 3：添加入站规则

```
类型：自定义
来源：你的IP/32
协议端口：TCP:22
策略：允许
备注：SFTP访问
```

---

### AWS EC2

#### 步骤 1：配置安全组

1. 进入 EC2 Dashboard
2. 选择你的实例
3. 点击 "安全" → "安全组"
4. 点击 "编辑入站规则"

#### 步骤 2：添加入站规则

```
类型：SSH
协议：TCP
端口范围：22
来源：你的IP/32
```

---

## 第二部分：服务器内部防火墙配置

### 使用 UFW（Ubuntu/Debian）

#### 查看UFW状态

```bash
sudo ufw status
```

#### 允许SSH/SFTP连接

```bash
# 允许SSH（端口22）
sudo ufw allow 22/tcp

# 允许特定IP的SSH
sudo ufw allow from 你的IP to any port 22

# 只允许特定IP的SSH（更安全）
sudo ufw allow from 192.168.1.100 to any port 22
```

#### 启用UFW

```bash
sudo ufw enable
sudo ufw status verbose
```

#### 删除规则

```bash
# 查看规则编号
sudo ufw status numbered

# 删除规则（根据编号）
sudo ufw delete 3
```

---

### 使用 iptables

#### 查看当前规则

```bash
sudo iptables -L -n
```

#### 添加规则

```bash
# 允许SSH（端口22）
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 只允许特定IP的SSH
sudo iptables -A INPUT -p tcp -s 你的IP --dport 22 -j ACCEPT

# 拒绝其他所有SSH访问
sudo iptables -A INPUT -p tcp --dport 22 -j DROP
```

#### 保存规则

```bash
# Ubuntu/Debian
sudo apt install iptables-persistent
sudo netfilter-persistent save

# CentOS/RHEL
sudo service iptables save
```

---

## 第三部分：配置SFTP（推荐）

### 为什么使用SFTP而不是FTP？

| 特性 | FTP | SFTP |
|------|-----|------|
| 加密 | ❌ 明文传输 | ✅ 基于SSH加密 |
| 端口 | 21（控制）+ 20（数据） | 22（与SSH相同） |
| 安全性 | 低 | 高 |
| 配置难度 | 复杂（需配置vsftpd） | 简单（使用SSH） |

---

### 配置SFTP用户（推荐）

#### 步骤 1：创建专用SFTP用户

```bash
# 创建新用户
sudo adduser voicemind

# 添加到sftp组
sudo usermod -G sftp voicemind

# 创建上传目录
sudo mkdir -p /var/www/downloads
sudo chown voicemind:voicemind /var/www/downloads
```

#### 步骤 2：限制SFTP用户权限

编辑SSH配置：

```bash
sudo nano /etc/ssh/sshd_config
```

添加或修改以下内容：

```bash
# 只允许特定用户使用SFTP
Match User voicemind
    ChrootDirectory /var/www/downloads
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
```

#### 步骤 3：重启SSH服务

```bash
sudo systemctl restart sshd
```

#### 步骤 4：测试SFTP连接

```bash
sftp voicemind@你的服务器IP
# 输入密码
sftp> ls  # 应该只能看到 /var/www/downloads 目录
```

---

### 使用Key认证（更安全）

#### 步骤 1：在本地生成SSH密钥

```bash
# Windows (PowerShell)
ssh-keygen -t rsa -b 4096

# macOS/Linux
ssh-keygen -t rsa -b 4096
```

#### 步骤 2：上传公钥到服务器

```bash
ssh-copy-id voicemind@你的服务器IP
```

#### 步骤 3：禁用密码登录

```bash
sudo nano /etc/ssh/sshd_config
```

修改：

```bash
PasswordAuthentication no
PubkeyAuthentication yes
```

重启SSH：

```bash
sudo systemctl restart sshd
```

---

## 第四部分：FTP服务器配置（如果必须使用FTP）

### 安装vsftpd

```bash
sudo apt update
sudo apt install vsftpd
```

### 配置vsftpd

```bash
sudo nano /etc/vsftpd.conf
```

关键配置：

```bash
# 允许本地用户登录
local_enable=YES

# 允许上传
write_enable=YES

# 限制用户只能访问自己的目录
chroot_local_user=YES
allow_writeable_chroot=YES

# 禁用匿名登录
anonymous_enable=NO

# 使用SSL/TLS加密（重要！）
ssl_enable=YES
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
```

### 添加FTP安全组规则（如果使用云服务器）

| 协议 | 端口范围 | 授权对象 | 说明 |
|------|---------|---------|------|
| TCP | 20/21 | 0.0.0.0/0 | FTP控制和数据端口 |
| TCP | 40000-40100 | 0.0.0.0/0 | FTP被动模式端口 |

### 重启服务

```bash
sudo systemctl restart vsftpd
sudo systemctl enable vsftpd
```

---

## 第五部分：安全最佳实践

### 1. 使用SFTP而非FTP

```
✅ SFTP（端口22）- 加密传输
❌ FTP（端口21）- 明文传输，不安全
```

### 2. 限制IP地址

```bash
# 只允许特定IP访问
sudo ufw allow from 你的IP to any port 22
```

### 3. 使用Key认证

```
✅ 公钥认证 - 安全、方便
⚠️ 密码认证 - 可被暴力破解
❌ 空密码 - 绝对禁止
```

### 4. 修改默认SSH端口

```bash
sudo nano /etc/ssh/sshd_config
# 找到 Port 22，改为其他端口如 2222
Port 2222
sudo systemctl restart sshd
```

### 5. 安装fail2ban防止暴力破解

```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 6. 定期检查日志

```bash
# 查看SSH登录尝试
sudo tail -f /var/log/auth.log

# 查看失败的登录
sudo grep "Failed password" /var/log/auth.log

# 查看SFTP活动
sudo tail -f /var/log/vsftpd.log
```

---

## 第六部分：快速检查清单

### SFTP配置（推荐）

- [ ] 安全组开放端口 22
- [ ] 防火墙允许端口 22
- [ ] 创建了专用SFTP用户
- [ ] 配置了chroot限制目录
- [ ] 测试了SFTP连接
- [ ] 配置了Key认证（推荐）

### FTP配置（不推荐）

- [ ] 安全组开放端口 20, 21
- [ ] 安全组开放被动端口 40000-40100
- [ ] 安装并配置了vsftpd
- [ ] 启用了SSL/TLS加密
- [ ] 测试了FTP连接

---

## 常见问题排查

### 问题1：连接被拒绝

```bash
# 检查端口是否开放
sudo ufw status
sudo netstat -tlnp | grep :22

# 检查服务是否运行
sudo systemctl status sshd
```

### 问题2：密码错误

```bash
# 重置用户密码
sudo passwd voicemind
```

### 问题3：权限不足

```bash
# 检查目录权限
ls -la /var/www/downloads

# 修改所有者
sudo chown voicemind:voicemind /var/www/downloads
```

---

## 下一步

配置完成后，你可以：

1. **上传网站文件**：使用SFTP上传到 `/var/www/html`
2. **上传Mac应用**：上传到 `/var/www/downloads/VoiceMind-Mac.dmg`
3. **更新官网链接**：在HTML中指向下载文件

需要我帮你执行任何具体的配置步骤吗？
