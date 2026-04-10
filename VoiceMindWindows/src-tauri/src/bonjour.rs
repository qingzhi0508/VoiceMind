use mdns_sd::{ServiceDaemon, ServiceInfo};
use tracing::{info, error, warn};

fn is_private_ipv4(ip: &str) -> bool {
    ip.starts_with("10.")
        || ip.starts_with("192.168.")
        || ip.starts_with("172.16.")
        || ip.starts_with("172.17.")
        || ip.starts_with("172.18.")
        || ip.starts_with("172.19.")
        || ip.starts_with("172.20.")
        || ip.starts_with("172.21.")
        || ip.starts_with("172.22.")
        || ip.starts_with("172.23.")
        || ip.starts_with("172.24.")
        || ip.starts_with("172.25.")
        || ip.starts_with("172.26.")
        || ip.starts_with("172.27.")
        || ip.starts_with("172.28.")
        || ip.starts_with("172.29.")
        || ip.starts_with("172.30.")
        || ip.starts_with("172.31.")
}

fn is_likely_virtual_interface(name_lower: &str) -> bool {
    name_lower.contains("loopback")
        || name_lower.contains("isatap")
        || name_lower.contains("teredo")
        || name_lower.contains("vethernet")
        || name_lower.contains("hyper-v")
        || name_lower.contains("wsl")
        || name_lower.contains("docker")
        || name_lower.contains("virtual")
        || name_lower.contains("meta")
        || name_lower.contains("vmware")
        || name_lower.contains("virtualbox")
        || name_lower.contains("tap")
        || name_lower.contains("tun")
        || name_lower.contains("tunnel")
        || name_lower.contains("vpn")
        || name_lower.contains("tailscale")
        || name_lower.contains("zerotier")
        || name_lower.contains("wireguard")
        || name_lower.contains("ktconnect")
}

fn parse_interface_state_line(line: &str) -> Option<(String, bool)> {
    let trimmed = line.trim();
    let trimmed_lower = trimmed.to_lowercase();
    if !(trimmed_lower.starts_with("enabled")
        || trimmed_lower.starts_with("disabled")
        || trimmed_lower.starts_with("宸插惎鐢?")
        || trimmed_lower.starts_with("宸叉柇寮€"))
    {
        return None;
    }

    let tokens: Vec<&str> = trimmed.split_whitespace().collect();
    if tokens.len() < 4 {
        return None;
    }

    let is_connected = !trimmed_lower.contains("disconnected")
        && !trimmed_lower.contains("宸叉柇寮€");
    let name = tokens[3..].join(" ").trim().to_string();
    if name.is_empty() {
        return None;
    }
    Some((name, is_connected))
}

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
        let service_type = "_voicerelay._tcp.local.";
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
        // 尝试多种方法获取真实局域网 IP

        // Method 1: 枚举网络适配器 (Windows) - netsh 方式，最可靠
        #[cfg(windows)]
        {
            if let Some(ip) = self.enumerate_adapters() {
                info!("Bonjour using enumerate_adapters IP: {}", ip);
                return Ok(ip);
            }
        }

        // Method 2: 尝试 UDP socket (可能返回虚拟 IP)
        if let Ok(socket) = std::net::UdpSocket::bind("0.0.0.0:0") {
            if socket.connect("8.8.8.8:80").is_ok() {
                if let Ok(addr) = socket.local_addr() {
                    let ip = addr.ip().to_string();
                    // 只接受有效的局域网 IP (排除 198.18/19.xx, 127.xx, 169.254.xx)
                    if !ip.starts_with("198.18.") && !ip.starts_with("198.19.") && !ip.starts_with("127.") && !ip.starts_with("169.254.") && ip != "0.0.0.0" {
                        info!("Bonjour using UDP socket IP: {}", ip);
                        return Ok(ip);
                    } else {
                        info!("Bonjour UDP returned virtual IP {}, trying other methods", ip);
                    }
                }
            }
        }

        // Method 3: local_ip_address crate 作为后备
        match local_ip_address::local_ip() {
            Ok(ip) => {
                let ip_str = ip.to_string();
                // 排除明显的虚拟 IP 段
                if !ip_str.starts_with("198.18.") && !ip_str.starts_with("198.19.") && !ip_str.starts_with("127.") {
                    info!("Bonjour using local_ip_address IP: {}", ip_str);
                    return Ok(ip_str);
                } else {
                    warn!("Bonjour: local_ip_address returned virtual IP {}, this may cause connection issues", ip_str);
                    // 仍然返回这个 IP，因为它是目前唯一能获得的
                    return Ok(ip_str);
                }
            }
            Err(e) => {
                warn!("Could not determine local IP via local_ip_address: {}", e);
            }
        }

        // 最后后备: 127.0.0.1
        warn!("Could not determine local IP, using localhost");
        Ok("127.0.0.1".to_string())
    }

    #[cfg(windows)]
    fn enumerate_adapters(&self) -> Option<String> {
        use std::os::windows::process::CommandExt;
        use std::process::Command;

        const CREATE_NO_WINDOW: u32 = 0x08000000;

        // First, get the list of interfaces with their admin states
        let interface_output = Command::new("netsh")
            .args(["interface", "show", "interface"])
            .creation_flags(CREATE_NO_WINDOW)
            .output();

        // Build a map of interface name -> connected state
        let mut interface_connected: std::collections::HashMap<String, bool> = std::collections::HashMap::new();

        if let Ok(output) = interface_output {
            let stdout = String::from_utf8_lossy(&output.stdout);
            info!("Bonjour netsh interface show interface:\n{}", stdout);

            for line in stdout.lines() {
                if let Some((name, is_connected)) = parse_interface_state_line(line) {
                    interface_connected.insert(name.clone(), is_connected);
                    info!("Bonjour: interface '{}' connected={} (robust parse)", name, is_connected);
                    continue;
                }
                let trimmed = line.trim();
                let trimmed_lower = trimmed.to_lowercase();
                // Check for both English "Enabled/Disabled" and Chinese "已启用/已断开连接"
                if trimmed_lower.starts_with("enabled") || trimmed_lower.starts_with("disabled")
                    || trimmed_lower.starts_with("已启用") || trimmed_lower.starts_with("已断开")
                {
                    // Check if connected (not disconnected)
                    let is_connected = !trimmed_lower.contains("disconnected")
                        && !trimmed_lower.contains("已断开");

                    // Extract interface name - it's typically at the end after the last whitespace
                    let name = trimmed.split_whitespace().last().unwrap_or("").trim().to_string();
                    if !name.is_empty() {
                        interface_connected.insert(name.clone(), is_connected);
                        info!("Bonjour: interface '{}' connected={}", name, is_connected);
                    }
                }
            }
        }

        // Use netsh to get interface IP addresses
        let output = Command::new("netsh")
            .args(["interface", "ipv4", "show", "addresses"])
            .creation_flags(CREATE_NO_WINDOW)
            .output()
            .ok()?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        info!("Bonjour netsh ipv4 addresses output:\n{}", stdout);

        // Collect all valid interfaces with their info
        #[derive(Debug)]
        struct InterfaceInfo {
            name: String,
            ip: Option<String>,
            has_gateway: bool,
            interface_metric: u32,
            is_connected: bool,
        }

        let mut interfaces: Vec<InterfaceInfo> = Vec::new();
        let mut current_name = String::new();
        let mut current_ip: Option<String> = None;
        let mut current_gateway = false;
        let mut current_metric: u32 = u32::MAX;

        for line in stdout.lines() {
            let trimmed = line.trim();
            let trimmed_lower = trimmed.to_lowercase();

            // Interface name line
            let is_interface_line = trimmed.starts_with("Interface \"")
                || trimmed.starts_with("Interface '")
                || (trimmed.starts_with("接口 \"") && trimmed.contains("的配置"));

            if is_interface_line {
                // Save previous interface
                if !current_name.is_empty() && current_ip.is_some() {
                    let is_connected = interface_connected.get(&current_name).copied().unwrap_or(true);
                    interfaces.push(InterfaceInfo {
                        name: current_name.clone(),
                        ip: current_ip.clone(),
                        has_gateway: current_gateway,
                        interface_metric: current_metric,
                        is_connected,
                    });
                }

                // Reset for new interface
                current_name = if let Some(start) = trimmed.find('"').map(|i| i + 1) {
                    if let Some(end) = trimmed[start..].find('"') {
                        trimmed[start..start + end].to_string()
                    } else {
                        String::new()
                    }
                } else if let Some(start) = trimmed.find('\'').map(|i| i + 1) {
                    if let Some(end) = trimmed[start..].find('\'') {
                        trimmed[start..start + end].to_string()
                    } else {
                        String::new()
                    }
                } else {
                    String::new()
                };

                current_ip = None;
                current_gateway = false;
                current_metric = u32::MAX;
                continue;
            }

            let name_lower = current_name.to_lowercase();

            // Skip virtual interfaces
            if is_likely_virtual_interface(&name_lower) || current_name.is_empty() {
                continue;
            }

            // Check for Interface Metric
            if trimmed_lower.contains("interfacemetric") && trimmed.contains(':') {
                if let Some(metric_str) = trimmed.split(':').last().map(|s| s.trim()) {
                    if let Ok(metric) = metric_str.parse::<u32>() {
                        current_metric = metric;
                    }
                }
            }

            // Check for default gateway
            if (trimmed_lower.starts_with("default gateway") || trimmed_lower.starts_with("默认网关"))
                && trimmed.contains(':')
            {
                if let Some(gateway) = trimmed.split(':').last().map(|s| s.trim()) {
                    if !gateway.is_empty() && gateway != "None" && !gateway.contains("::") {
                        current_gateway = true;
                    }
                }
            }

            // Check for IP address
            if (trimmed_lower.starts_with("ip address") || trimmed_lower.starts_with("ip 地址"))
                && trimmed.contains(':')
            {
                if let Some(ip) = trimmed.split(':').last().map(|s| s.trim()) {
                    if ip.contains('.') && !ip.starts_with("0.") && !ip.is_empty() && ip != "0.0.0.0" {
                        current_ip = Some(ip.to_string());
                    }
                }
            }
        }

        // Don't forget the last interface
        if !current_name.is_empty() && current_ip.is_some() {
            let is_connected = interface_connected.get(&current_name).copied().unwrap_or(true);
            interfaces.push(InterfaceInfo {
                name: current_name,
                ip: current_ip,
                has_gateway: current_gateway,
                interface_metric: current_metric,
                is_connected,
            });
        }

        // Filter: only consider connected interfaces with gateways
        // Also filter out interfaces with virtual/benchmarking IPs (198.18.x.x)
        interfaces.retain(|i| {
            let ip_lower = i.ip.as_ref().unwrap_or(&String::new()).to_lowercase();
            i.has_gateway
                && i.is_connected
                && i.interface_metric != u32::MAX
                && !ip_lower.starts_with("198.18.")
                && !ip_lower.starts_with("198.19.")
        });
        interfaces.sort_by_key(|i| {
            let ip = i.ip.as_deref().unwrap_or("");
            let private_rank = if is_private_ipv4(ip) { 0 } else { 1 };
            let virtual_rank = if is_likely_virtual_interface(&i.name.to_lowercase()) { 1 } else { 0 };
            (private_rank, virtual_rank, i.interface_metric)
        });

        info!("Bonjour enumerate_adapters: found {} valid connected interfaces", interfaces.len());

        // Select interface with lowest metric (currently active network)
        if let Some(intf) = interfaces.first() {
            let ip = intf.ip.as_deref().unwrap_or("");
            info!(
                "Bonjour enumerate_adapters: selected interface '{}' with IP {} (metric: {}, private_lan: {}, virtual_like: {})",
                intf.name,
                ip,
                intf.interface_metric,
                is_private_ipv4(ip),
                is_likely_virtual_interface(&intf.name.to_lowercase())
            );
            return intf.ip.clone();
        }

        info!("Bonjour enumerate_adapters: no eligible interface found after filtering");
        None
    }

    /// Extract IPv4 address from an adapter block of ipconfig output
    fn extract_ipv4_from_block(block: &str) -> Option<String> {
        for line in block.lines() {
            let trimmed = line.trim();
            if trimmed.contains("IPv4") && trimmed.contains(":") {
                if let Some(ip) = trimmed.split(':').last().map(|s| s.trim().to_string()) {
                    if !ip.is_empty()
                        && ip != "0.0.0.0"
                        && !ip.starts_with("127.")
                        && !ip.starts_with("169.254.")
                        && !ip.starts_with("198.18.")
                        && !ip.starts_with("198.19.")
                    {
                        return Some(ip);
                    }
                }
            }
        }
        None
    }

    #[cfg(not(windows))]
    fn enumerate_adapters(&self) -> Option<String> {
        None
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
