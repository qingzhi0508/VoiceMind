# VoiceMind 官网部署指南

## 服务器环境
- **操作系统**: Ubuntu/Debian Linux
- **访问方式**: SFTP
- **Web服务器**: Nginx (推荐)

---

## 第一部分：上传网站文件

### 步骤 1.1：连接SFTP

使用以下命令连接服务器（替换为你的服务器IP和用户名）：

```bash
sftp username@your-server-ip
```

输入密码后，你将进入SFTP交互界面。

### 步骤 1.2：上传文件

在SFTP中执行以下命令：

```bash
# 进入你的网站目录（根据你的配置调整）
cd /var/www/html

# 或者如果是新域名
cd /var/www/voicemind.app

# 上传整个website文件夹
put -r local/path/to/website/* .

# 或者如果要在服务器上创建子目录
mkdir voiceMind
cd voiceMind
put -r local/path/to/website/* .
```

### 备选方案：使用FileZilla等GUI工具

1. 下载安装 [FileZilla Client](https://filezilla-project.org/)
2. 打开"站点管理器"（Ctrl+S）
3. 配置新站点：
   - **协议**: SFTP - SSH File Transfer Protocol
   - **主机**: 你的服务器IP
   - **端口**: 22
   - **用户**: 你的用户名
   - **密码**: 你的密码
4. 连接后导航到 `/var/www/html` 或你想要的目录
5. 将website文件夹中的所有文件拖拽上传

---

## 第二部分：配置Web服务器

### 方案A：使用Nginx（推荐）

#### 步骤 2.1：安装Nginx

SSH连接到服务器后执行：

```bash
sudo apt update
sudo apt install nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### 步骤 2.2：创建网站配置

```bash
sudo nano /etc/nginx/sites-available/voicemind
```

添加以下配置：

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    
    root /var/www/voicemind;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # 启用Gzip压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    # 缓存静态资源
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

#### 步骤 2.3：启用站点

```bash
# 创建符号链接
sudo ln -s /etc/nginx/sites-available/voicemind /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重载Nginx
sudo systemctl reload nginx
```

### 方案B：使用Apache

#### 步骤 2.1：安装Apache

```bash
sudo apt update
sudo apt install apache2
sudo systemctl start apache2
sudo systemctl enable apache2
```

#### 步骤 2.2：创建虚拟主机配置

```bash
sudo nano /etc/apache2/sites-available/voicemind.conf
```

添加以下配置：

```apache
<VirtualHost *:80>
    ServerName your-domain.com
    ServerAlias www.your-domain.com
    DocumentRoot /var/www/voicemind
    
    <Directory /var/www/voicemind>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/voicemind_error.log
    CustomLog ${APACHE_LOG_DIR}/voicemind_access.log combined
</VirtualHost>
```

#### 步骤 2.3：启用站点

```bash
sudo a2ensite voicemind.conf
sudo a2enmod rewrite
sudo systemctl reload apache2
```

---

## 第三部分：配置域名（可选）

### 如果你使用域名

#### 步骤 3.1：添加DNS记录

在你的域名提供商处添加A记录：

```
类型: A
名称: @ (或 www)
值: 你的服务器IP
TTL: 3600
```

#### 步骤 3.2：等待DNS生效

DNS传播通常需要几分钟到48小时。

### 如果你没有域名

可以直接通过服务器IP访问：

```
http://你的服务器IP/index.html
```

---

## 第四部分：配置HTTPS（强烈推荐）

### 使用Let's Encrypt免费SSL

#### 步骤 4.1：安装Certbot

```bash
sudo apt install certbot python3-certbot-nginx
```

#### 步骤 4.2：获取SSL证书

```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

#### 步骤 4.3：自动续期测试

```bash
sudo certbot renew --dry-run
```

Certbot会自动设置自动续期任务。

---

## 第五部分：验证部署

### 本地测试

在浏览器中访问：

```
http://your-domain.com
# 或
http://你的服务器IP/index.html
```

### 常见问题排查

#### 1. 403 Forbidden 错误

```bash
# 检查文件权限
sudo chmod -R 755 /var/www/voicemind
sudo chown -R www-data:www-data /var/www/voicemind

# 如果使用Nginx
sudo chown -R www-data:www-data /var/www/voicemind
```

#### 2. 404 Not Found 错误

确保Nginx配置中的`root`路径正确指向你的网站文件：

```bash
ls -la /var/www/voicemind/
```

#### 3. Nginx日志位置

```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

---

## 第六部分：性能优化（可选）

### 1. 启用HTTP/2

Nginx配置中修改：

```nginx
listen 443 ssl http2;
```

### 2. 使用CDN加速

考虑使用CloudFlare免费CDN：

1. 注册 [CloudFlare](https://cloudflare.com)
2. 将域名的DNS服务器改为CloudFlare
3. 免费获得SSL和CDN加速

### 3. 配置缓存头

在Nginx配置中添加：

```nginx
location ~* \.(html|css|js)$ {
    expires 1h;
    add_header Cache-Control "public, max-age=3600";
}
```

---

## 快速检查清单

- [ ] SFTP连接成功
- [ ] 文件上传完成
- [ ] Nginx/Apache安装并运行
- [ ] 配置文件已启用
- [ ] 防火墙开放80/443端口
- [ ] 测试访问成功
- [ ] 配置SSL证书（推荐）
- [ ] 域名DNS解析正确（如果使用域名）

---

## 常用命令参考

```bash
# Nginx命令
sudo systemctl restart nginx    # 重启
sudo systemctl reload nginx     # 重载配置
sudo nginx -t                    # 测试配置

# Apache命令
sudo systemctl restart apache2   # 重启
sudo systemctl reload apache2    # 重载配置

# 文件权限
sudo chmod -R 755 /var/www/      # 设置权限
sudo chown -R www-data:www-data /var/www/  # 设置所有者

# 防火墙
sudo ufw allow 'Nginx Full'       # 开放端口
sudo ufw status                   # 查看状态
```

---

## 下一步

1. **替换下载链接**：编辑 `index.html` 中的Mac和iOS下载链接
2. **配置分析工具**：添加Google Analytics等统计代码
3. **SEO优化**：配置sitemap.xml和robots.txt
4. **监控**：设置 uptime monitoring

如有问题，随时询问！
