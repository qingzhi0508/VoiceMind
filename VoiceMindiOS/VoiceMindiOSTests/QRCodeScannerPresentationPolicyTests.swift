import Testing
@testable import VoiceMind

struct QRCodeScannerPresentationPolicyTests {
    @Test
    func previewShowsAsSoonAsLayerExists() {
        #expect(QRCodeScannerPresentationPolicy.showsPreview(previewLayerAvailable: true))
        #expect(!QRCodeScannerPresentationPolicy.showsPreview(previewLayerAvailable: false))
    }

    @Test
    func startupOverlayOnlyShowsWhileWaitingForScannerToRun() {
        #expect(QRCodeScannerPresentationPolicy.showsStartupOverlay(isScanning: false))
        #expect(!QRCodeScannerPresentationPolicy.showsStartupOverlay(isScanning: true))
    }
}
