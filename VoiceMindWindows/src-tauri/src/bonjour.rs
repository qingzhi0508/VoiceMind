pub struct BonjourService {
    service_name: String,
    port: u16,
    instance_name: String,
}

impl BonjourService {
    pub fn new(instance_name: &str, port: u16) -> Self {
        todo!()
    }
    pub async fn start(&self) -> Result<(), String> {
        todo!()
    }
    pub async fn stop(&self) {
        todo!()
    }
    pub async fn update(&self, port: u16) {
        todo!()
    }
}
