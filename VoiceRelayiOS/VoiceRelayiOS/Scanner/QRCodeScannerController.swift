import AVFoundation
import Combine
import SwiftUI
import AudioToolbox

class QRCodeScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    @Published var error: String?
    @Published var isScanning = false

    private var captureSession: AVCaptureSession?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "VoiceRelay.QRCodeScanner.session")

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
        guard !isScanning else { return previewLayer }

        #if targetEnvironment(simulator)
        error = "模拟器不支持相机扫码，请使用真机或改用手动输入连接信息。"
        return nil
        #else
        error = nil
        scannedCode = nil

        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        let videoCaptureDevice =
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ??
            AVCaptureDevice.default(for: .video)

        guard let videoCaptureDevice else {
            captureSession.commitConfiguration()
            error = "无法访问相机"
            return nil
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            captureSession.commitConfiguration()
            self.error = "无法初始化相机输入"
            return nil
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            captureSession.commitConfiguration()
            error = "无法添加相机输入"
            return nil
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            captureSession.commitConfiguration()
            error = "无法添加元数据输出"
            return nil
        }

        captureSession.commitConfiguration()

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill

        self.captureSession = captureSession
        self.previewLayer = previewLayer

        sessionQueue.async {
            captureSession.startRunning()
            DispatchQueue.main.async {
                self.isScanning = true
            }
        }

        return previewLayer
        #endif
    }

    func stopScanning() {
        let session = captureSession

        sessionQueue.async {
            if session?.isRunning == true {
                session?.stopRunning()
            }
        }

        captureSession = nil
        previewLayer = nil
        isScanning = false
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
