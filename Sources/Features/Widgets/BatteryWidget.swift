import SwiftUI
import IOKit.ps

struct BatteryWidget: View {
    @State private var batteryLevel: Int = 0
    @State private var isCharging: Bool = false
    @State private var timeRemaining: String = ""

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            // Battery ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 6)
                    .frame(width: 80, height: 80)

                // Progress ring
                Circle()
                    .trim(from: 0, to: Double(batteryLevel) / 100.0)
                    .stroke(
                        batteryGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: batteryLevel)

                // Center content
                VStack(spacing: 2) {
                    if isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                    }
                    Text("\(batteryLevel)%")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 4) {
                Text(isCharging ? "Charging" : "Battery")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                if !timeRemaining.isEmpty {
                    Text(timeRemaining)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(20)
        .frame(width: 160, height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear { updateBattery() }
        .onReceive(timer) { _ in updateBattery() }
    }

    private var batteryGradient: LinearGradient {
        if batteryLevel <= 20 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        } else if batteryLevel <= 50 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func updateBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else { return }

        batteryLevel = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let charging = description[kIOPSIsChargingKey] as? Bool ?? false
        isCharging = charging

        if let minutes = description[kIOPSTimeToEmptyKey] as? Int, minutes > 0, !charging {
            let hours = minutes / 60
            let mins = minutes % 60
            timeRemaining = hours > 0 ? "\(hours)h \(mins)m left" : "\(mins)m left"
        } else if let minutes = description[kIOPSTimeToFullChargeKey] as? Int, minutes > 0, charging {
            let hours = minutes / 60
            let mins = minutes % 60
            timeRemaining = hours > 0 ? "\(hours)h \(mins)m to full" : "\(mins)m to full"
        } else {
            timeRemaining = ""
        }
    }
}
