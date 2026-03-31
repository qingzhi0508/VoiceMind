import AVFoundation
import Testing
import UIKit
@testable import VoiceMind

@MainActor
struct CameraPreviewTests {
    @Test
    func previewContainerUsesBlackFallbackBackgroundAndHostsPreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer()
        let view = CameraPreviewContainerView(previewLayer: previewLayer)

        view.frame = CGRect(x: 0, y: 0, width: 240, height: 320)
        view.layoutIfNeeded()

        #expect(view.backgroundColor == .black)
        #expect(previewLayer.superlayer === view.layer)
        #expect(previewLayer.frame == view.bounds)
    }
}
