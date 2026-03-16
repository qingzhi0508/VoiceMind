import AVFoundation
import Combine
import SwiftUI

class QRCodeScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    @Published var error: String?
    @Published var isScanning = false

    private var captureSession: AVCaptureSession?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

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

        let captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            error = "无法访问相机"
            return nil
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            self.error = "无法初始化相机输入"
            return nil
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            error = "无法添加相机输入"
            return nil
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            error = "无法添加元数据输出"
            return nil
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill

        self.captureSession = captureSession
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
            DispatchQueue.main.async {
                self.isScanning = true
            }
        }

        return previewLayer
    }

    func stopScanning() {
        captureSession?.stopRunning()
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
