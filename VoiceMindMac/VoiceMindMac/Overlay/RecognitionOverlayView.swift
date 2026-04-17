import SwiftUI

struct RecognitionOverlayView: View {
    @ObservedObject var viewModel: RecognitionOverlayViewModel

    var body: some View {
        overlayContent
            .opacity(viewModel.state == .hidden ? 0 : 1)
            .animation(.easeInOut(duration: 0.15), value: viewModel.state)
    }

    private var overlayContent: some View {
        ZStack(alignment: .topLeading) {
            rainbowBackground

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.55)

            HStack(alignment: .top, spacing: 10) {
                spinnerView
                textView
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
    }

    private var rainbowBackground: some View {
        TimelineView(.animation(minimumInterval: 0.03)) { timeline in
            let degrees = (timeline.date.timeIntervalSinceReferenceDate * 40).truncatingRemainder(dividingBy: 360)
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.42, blue: 0.42),
                    Color(red: 1.0, green: 0.66, blue: 0.30),
                    Color(red: 1.0, green: 0.83, blue: 0.23),
                    Color(red: 0.41, green: 0.86, blue: 0.49),
                    Color(red: 0.30, green: 0.67, blue: 0.97),
                    Color(red: 0.59, green: 0.46, blue: 0.98),
                    Color(red: 0.94, green: 0.40, blue: 0.58),
                    Color(red: 1.0, green: 0.42, blue: 0.42)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .hueRotation(.degrees(degrees))
        }
    }

    @ViewBuilder
    private var spinnerView: some View {
        if showSpinner {
            TimelineView(.animation(minimumInterval: 0.02)) { timeline in
                let degrees = (timeline.date.timeIntervalSinceReferenceDate * 360 / 0.7).truncatingRemainder(dividingBy: 360)
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2.5)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(degrees))
                    )
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var textView: some View {
        Group {
            switch viewModel.state {
            case .listening:
                Text("正在聆听...")
            case .streaming(let text):
                Text(text)
            case .result(let text):
                Text(text)
            case .error(let message):
                Text(message)
            case .hidden:
                EmptyView()
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.24), radius: 1, y: 1)
        .lineLimit(3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showSpinner: Bool {
        switch viewModel.state {
        case .listening, .streaming: return true
        case .result, .error, .hidden: return false
        }
    }
}
