import SwiftUI

struct ClockWidget: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            VStack(spacing: 6) {
                // Time — use manual formatting to avoid locale-dependent wrapping
                Text(timeString(from: date))
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(secondsString(from: date))
                    .font(.system(size: 14, weight: .light, design: .monospaced))
                    .foregroundStyle(NotchConstants.accentGlow.opacity(0.8))

                RoundedRectangle(cornerRadius: 0.5)
                    .fill(.white.opacity(0.12))
                    .frame(width: 36, height: 1)
                    .padding(.vertical, 2)

                Text(dateString(from: date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(16)
            .frame(width: 160, height: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func secondsString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ss"
        return formatter.string(from: date)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
