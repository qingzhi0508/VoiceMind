import SwiftUI
import Combine

class RecognitionOverlayPanel: NSPanel {
    private let viewModel: RecognitionOverlayViewModel
    private let positionTracker: CursorPositionTracker

    init(viewModel: RecognitionOverlayViewModel) {
        self.viewModel = viewModel
        self.positionTracker = CursorPositionTracker()

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 80),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .statusBar + 1
        self.ignoresMouseEvents = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: RecognitionOverlayView(viewModel: viewModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 80)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView

        positionTracker.onPositionUpdate = { [weak self] position in
            self?.repositionNearCursor(position)
        }

        observeViewModelState()
    }

    private func observeViewModelState() {
        viewModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .hidden:
                    self.orderOut(nil)
                    self.positionTracker.stopTracking()
                default:
                    // Immediately position before showing
                    let pos = self.positionTracker.currentPosition()
                    self.repositionNearCursor(pos)
                    self.positionTracker.startTracking()
                    self.orderFrontRegardless()
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func repositionNearCursor(_ cursorPoint: NSPoint) {
        let panelWidth: CGFloat = 520
        let panelHeight: CGFloat = 80
        let yOffset: CGFloat = 20

        var x = cursorPoint.x - 10
        var y = cursorPoint.y - yOffset - panelHeight

        // Keep within screen bounds
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            if x + panelWidth > screenFrame.maxX {
                x = screenFrame.maxX - panelWidth - 8
            }
            if x < screenFrame.minX {
                x = screenFrame.minX + 8
            }
            if y < screenFrame.minY {
                // Flip below cursor
                y = cursorPoint.y + yOffset
            }
            if y + panelHeight > screenFrame.maxY {
                y = screenFrame.maxY - panelHeight
            }
        }

        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
