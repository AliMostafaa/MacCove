import SwiftUI
import IOKit
import IOKit.ps

struct BatteryWidget: View {
    @State private var batteryLevel: Int = 0
    @State private var isCharging: Bool = false
    @State private var isPluggedIn: Bool = false
    @State private var isFullyCharged: Bool = false
    @State private var timeRemaining: String = ""
    @State private var watts: Double = 0

    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            // Battery ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: Double(batteryLevel) / 100.0)
                    .stroke(ringGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: batteryLevel)

                VStack(spacing: 2) {
                    if isFullyCharged {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                    } else if isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.yellow)
                    } else if isPluggedIn {
                        Image(systemName: "bolt.slash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Text("\(batteryLevel)%")
                        .font(.system(size: isPluggedIn ? 16 : 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 5) {
                // Status label
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                // Wattage pill
                if watts > 0.5 {
                    HStack(spacing: 3) {
                        Image(systemName: isCharging ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8, weight: .semibold))
                        Text(formattedWatts)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isCharging ? Color.yellow.opacity(0.9) : .white.opacity(0.45))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isCharging ? Color.yellow.opacity(0.12) : .white.opacity(0.06))
                    )
                }

                // Time remaining
                if !timeRemaining.isEmpty {
                    Text(timeRemaining)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
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

    // MARK: - Computed

    private var statusLabel: String {
        if isFullyCharged { return "Fully Charged" }
        if isCharging     { return "Charging" }
        if isPluggedIn    { return "Plugged In" }
        return "On Battery"
    }

    private var statusColor: Color {
        if isFullyCharged     { return .green }
        if isCharging         { return .yellow }
        if isPluggedIn        { return .white.opacity(0.4) }
        if batteryLevel <= 20 { return .red }
        return .white.opacity(0.25)
    }

    private var formattedWatts: String {
        watts >= 10 ? String(format: "%.0f W", watts) : String(format: "%.1f W", watts)
    }

    private var ringGradient: LinearGradient {
        if isFullyCharged {
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        }
        if isCharging {
            return LinearGradient(colors: [.yellow.opacity(0.7), .yellow], startPoint: .leading, endPoint: .trailing)
        }
        if batteryLevel <= 20 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        } else if batteryLevel <= 50 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Data

    private func updateBattery() {
        // ── IOPowerSources: level, charging state ──────────────────────────────
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources  = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
           let source   = sources.first,
           let info     = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {

            batteryLevel   = info[kIOPSCurrentCapacityKey] as? Int  ?? batteryLevel
            isCharging     = info[kIOPSIsChargingKey]      as? Bool ?? false
            isFullyCharged = info[kIOPSIsChargedKey]       as? Bool ?? false
            let state      = info[kIOPSPowerSourceStateKey] as? String ?? ""
            isPluggedIn    = (state == kIOPSACPowerValue)
        }

        // ── AppleSmartBattery: accurate watts + time ───────────────────────────
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        func prop<T>(_ key: String) -> T? {
            IORegistryEntryCreateCFProperty(service, key as CFString,
                                            kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? T
        }

        // Voltage in mV
        let voltageMV: Int = prop("Voltage") ?? 0

        // InstantAmperage — Apple Silicon stores as unsigned 32-bit; treat as signed
        // Fall back to Amperage (average) if instant is unavailable
        var rawAmperage: Int = prop("InstantAmperage") ?? 0
        if rawAmperage == 0 { rawAmperage = prop("Amperage") ?? 0 }
        if rawAmperage > 2_000_000_000 { rawAmperage -= 4_294_967_296 }

        if voltageMV > 0 && rawAmperage != 0 {
            watts = abs(Double(rawAmperage) * Double(voltageMV)) / 1_000_000.0
        } else {
            watts = 0
        }

        // Time remaining — 65535 means "still calculating", filter that out
        timeRemaining = ""
        if !isPluggedIn {
            // Prefer instant TimeRemaining, fall back to smoothed AvgTimeToEmpty
            let mins: Int = {
                let t: Int = prop("TimeRemaining") ?? 0
                return (t > 0 && t < 65535) ? t : (prop("AvgTimeToEmpty") ?? 0)
            }()
            if mins > 0 && mins < 65535 {
                let h = mins / 60, m = mins % 60
                timeRemaining = h > 0 ? "\(h)h \(m)m left" : "\(m)m left"
            }
        } else if isCharging {
            let mins: Int = prop("AvgTimeToFull") ?? 0
            if mins > 0 && mins < 65535 {
                let h = mins / 60, m = mins % 60
                timeRemaining = h > 0 ? "\(h)h \(m)m to full" : "\(m)m to full"
            }
        }
    }
}
