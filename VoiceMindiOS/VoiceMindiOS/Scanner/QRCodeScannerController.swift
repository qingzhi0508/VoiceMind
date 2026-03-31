import AVFoundation
import Combine
import SwiftUI
import AudioToolbox

class QRCodeScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    @Published var error: String?
    @Published var isScanning = false
    @Published var isPreviewReady = false  // 相机预览是否真正启动

    private var captureSession: AVCaptureSession?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "VoiceMind.QRCodeScanner.session")
    private var isStarting = false  // 防止重复启动
    private var pendingStop = false  // 是否需要停止（用于配置过程中收到停止请求）

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.error = "需要相机权限才能扫描二维码。请在设置中允许访问相机。"
                completion(false)
            }
        @unknown default:
            completion(false)
        }
    }

    func startScanning() -> AVCaptureVideoPreviewLayer? {
        guard !isScanning, !isStarting else { return previewLayer }

        #if targetEnvironment(simulator)
        error = "模拟器不支持相机扫码，请使用真机或改用手动输入连接信息。"
        return nil
        #else
        error = nil
        scannedCode = nil
        isStarting = true
        isPreviewReady = false
        sessionQueue.async { [weak self] in
            self?.configureAndStartSession()
        }

        return previewLayer
        #endif
    }

    func stopScanning() {
        // 如果正在启动中，标记为需要停止，让启动流程处理
        if isStarting {
            pendingStop = true
            return
        }

        let session = captureSession
        sessionQueue.async {
            if session?.isRunning == true {
                session?.stopRunning()
            }
        }

        DispatchQueue.main.async {
            self.captureSession = nil
            self.previewLayer = nil
            self.isScanning = false
            self.isStarting = false
            self.isPreviewReady = false
            self.pendingStop = false
        }
    }

    private func configureAndStartSession() {
        guard !pendingStop else {
            publishStoppedState()
            return
        }

        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        let videoCaptureDevice =
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ??
            AVCaptureDevice.default(for: .video)

        guard let videoCaptureDevice else {
            captureSession.commitConfiguration()
            publishStartupFailure("无法访问相机")
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            captureSession.commitConfiguration()
            publishStartupFailure("无法初始化相机输入")
            return
        }

        guard captureSession.canAddInput(videoInput) else {
            captureSession.commitConfiguration()
            publishStartupFailure("无法添加相机输入")
            return
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            captureSession.commitConfiguration()
            publishStartupFailure("无法添加元数据输出")
            return
        }

        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        guard !pendingStop else {
            captureSession.commitConfiguration()
            publishStoppedState()
            return
        }

        captureSession.commitConfiguration()

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill

        DispatchQueue.main.async {
            guard !self.pendingStop else {
                self.publishStoppedState()
                return
            }

            self.captureSession = captureSession
            self.previewLayer = previewLayer
            self.isPreviewReady = true
        }

        captureSession.startRunning()

        DispatchQueue.main.async {
            guard !self.pendingStop else {
                self.stopScanning()
                return
            }

            self.isStarting = false
            self.isScanning = captureSession.isRunning
        }
    }

    private func publishStartupFailure(_ message: String) {
        DispatchQueue.main.async {
            self.captureSession = nil
            self.previewLayer = nil
            self.isStarting = false
            self.isScanning = false
            self.isPreviewReady = false
            self.pendingStop = false
            self.error = message
        }
    }

    private func publishStoppedState() {
        DispatchQueue.main.async {
            self.captureSession = nil
            self.previewLayer = nil
            self.isStarting = false
            self.isScanning = false
            self.isPreviewReady = false
            self.pendingStop = false
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }

            // Found a QR code
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            scannedCode = stringValue
            stopScanning()
        }
    }
}
