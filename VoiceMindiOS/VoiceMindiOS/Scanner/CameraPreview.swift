import SwiftUI
import AVFoundation
import UIKit

final class CameraPreviewContainerView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        didSet {
            oldValue.removeFromSuperlayer()
            attachPreviewLayerIfNeeded()
            setNeedsLayout()
        }
    }

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        backgroundColor = .black
        isOpaque = true
        clipsToBounds = true
        attachPreviewLayerIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    private func attachPreviewLayerIfNeeded() {
        guard previewLayer.superlayer !== layer else { return }
        layer.addSublayer(previewLayer)
    }
}

struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        CameraPreviewContainerView(previewLayer: previewLayer)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewView = uiView as? CameraPreviewContainerView else { return }
        previewView.previewLayer = previewLayer
        previewView.setNeedsLayout()
        previewView.layoutIfNeeded()
    }
}
