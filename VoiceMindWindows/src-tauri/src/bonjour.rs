use std::process::Stdio;
use tokio::process::Command;
use tracing::{info, error};

pub struct BonjourService {
    service_name: String,
    port: u16,
    instance_name: String,
    child: Option<tokio::process::Child>,
}

impl BonjourService {
    pub fn new(instance_name: &str, port: u16) -> Self {
        Self {
            service_name: "VoiceMind".to_string(),
            port,
            instance_name: instance_name.to_string(),
            child: None,
        }
    }

    /// 启动 Bonjour 广播
    /// 使用 dns-sd.exe - 苹果提供的 Windows Bonjour 工具
    /// 命令: dns-sd.exe -r "VoiceMind-{hostname}" _voicemind._tcp local. {port}
    pub async fn start(&mut self) -> Result<(), String> {
        let instance_name = format!("{}-{}", self.service_name, self.instance_name);

        info!("Starting Bonjour broadcast: {} on port {}", instance_name, self.port);

        // 检查 dns-sd.exe 是否存在
        let dns_sd_path = self.find_dns_sd().ok_or("dns-sd.exe not found")?;

        // 启动 dns-sd 进程
        let child = Command::new(&dns_sd_path)
            .args(&[
                "-r", &instance_name,
                "_voicemind._tcp", "local.",
                &self.port.to_string(),
            ])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("Failed to start dns-sd: {}", e))?;

        self.child = Some(child);
        info!("Bonjour broadcast started successfully");
        Ok(())
    }

    /// 停止 Bonjour 广播
    pub async fn stop(&mut self) {
        if let Some(mut child) = self.child.take() {
            info!("Stopping Bonjour broadcast");
            child.kill().await.ok();
        }
    }

    /// 更新端口
    pub async fn update(&mut self, port: u16) -> Result<(), String> {
        // 停止旧服务
        self.stop().await;
        // 启动新端口
        self.port = port;
        self.start().await
    }

    /// 查找 dns-sd.exe 路径
    fn find_dns_sd(&self) -> Option<String> {
        // Windows 上通常在以下位置
        let paths = [
            "C:\\Program Files\\Bonjour\\dns-sd.exe",
            "C:\\Program Files (x86)\\Bonjour\\dns-sd.exe",
        ];
        for path in &paths {
            if std::path::Path::new(path).exists() {
                return Some(path.to_string());
            }
        }
        None
    }
}

impl Drop for BonjourService {
    fn drop(&mut self) {
        // 确保进程被清理
        if let Some(mut child) = self.child.take() {
            let _ = child.kill();
        }
    }
}
