import CoreGraphics

enum TranscriptAutoScrollPolicy {
    static func shouldAutoScroll(
        contentHeight: CGFloat,
        visibleHeight: CGFloat
    ) -> Bool {
        guard visibleHeight > 0 else { return false }
        return contentHeight > visibleHeight * 0.5
    }
}
