import SwiftUI

struct WatchProgressRing: View {
    let progress: Double
    let tint: Color
    var trackTint: Color? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke((trackTint ?? tint).opacity(0.28), lineWidth: 5)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
