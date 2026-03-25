use mdns_sd::{ServiceDaemon, ServiceInfo};
use tracing::{info, error, warn};

pub struct BonjourService {
    service_name: String,
    port: u16,
    instance_name: String,
    daemon: Option<ServiceDaemon>,
    registered: bool,
}

impl BonjourService {
    pub fn new(instance_name: &str, port: u16) -> Self {
        Self {
            service_name: "VoiceMind".to_string(),
            port,
            instance_name: instance_name.to_string(),
            daemon: None,
            registered: false,
        }
    }

    /// 启动 Bonjour 广播
    /// 使用原生 mDNS 实现，无需外部依赖
    pub async fn start(&mut self) -> Result<(), String> {
        let instance_name = format!("{}-{}", self.service_name, self.instance_name);

        info!("Starting Bonjour broadcast: {} on port {}", instance_name, self.port);

        // 创建 mDNS 守护进程
        let daemon = ServiceDaemon::new()
            .map_err(|e| format!("Failed to create mDNS daemon: {}", e))?;

        // 创建服务信息
        let service_type = "_voicemind._tcp.local.";
        let host_ipv4 = self.get_local_ip()?;
        
        let service_info = ServiceInfo::new(
            service_type,
            &instance_name,
            &format!("{}.local.", instance_name),
            host_ipv4,
            self.port,
            None, // 不需要额外的 TXT 记录
        )
        .map_err(|e| format!("Failed to create service info: {}", e))?;

        // 注册服务
        daemon.register(service_info)
            .map_err(|e| format!("Failed to register service: {}", e))?;

        self.daemon = Some(daemon);
        self.registered = true;
        
        info!("Bonjour broadcast started successfully");
        Ok(())
    }

    /// 停止 Bonjour 广播
    pub async fn stop(&mut self) {
        if let Some(daemon) = self.daemon.take() {
            info!("Stopping Bonjour broadcast");
            // 优雅关闭
            if let Err(e) = daemon.shutdown() {
                error!("Error shutting down mDNS daemon: {}", e);
            }
        }
        self.registered = false;
    }

    /// 更新端口
    pub async fn update(&mut self, port: u16) -> Result<(), String> {
        // 停止旧服务
        self.stop().await;
        // 启动新端口
        self.port = port;
        self.start().await
    }

    /// 获取本地 IP 地址
    fn get_local_ip(&self) -> Result<String, String> {
        // 尝试获取本机 IP
        match local_ip_address::local_ip() {
            Ok(ip) => Ok(ip.to_string()),
            Err(_) => {
                // 如果获取失败，使用 127.0.0.1 作为后备
                warn!("Could not determine local IP, using localhost");
                Ok("127.0.0.1".to_string())
            }
        }
    }

    /// 检查服务是否正在运行
    pub fn is_running(&self) -> bool {
        self.registered && self.daemon.is_some()
    }
}

impl Drop for BonjourService {
    fn drop(&mut self) {
        // 确保服务被清理
        if let Some(daemon) = self.daemon.take() {
            let _ = daemon.shutdown();
        }
    }
}