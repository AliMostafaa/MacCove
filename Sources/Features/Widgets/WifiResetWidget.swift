import SwiftUI
import CoreWLAN
import Network

struct WifiResetWidget: View {
    @State private var isConnected: Bool = false
    @State private var isWifiOn: Bool = false
    @State private var ssid: String? = nil
    @State private var signalBars: Int = 0
    @State private var resetState: ResetState = .idle

    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    enum ResetState {
        case idle, turningOff, turningOn, reconnecting
        var label: String {
            switch self {
            case .idle:         return "Reset WiFi"
            case .turningOff:   return "Turning off…"
            case .turningOn:    return "Turning on…"
            case .reconnecting: return "Reconnecting…"
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 80, height: 80)

                Image(systemName: isConnected ? "wifi" : (isWifiOn ? "wifi.exclamationmark" : "wifi.slash"))
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(iconColor)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, isActive: resetState != .idle)
            }

            VStack(spacing: 3) {
                Text(statusLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                if let ssid, resetState == .idle {
                    Text(ssid)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 120)
                }

                if isConnected && resetState == .idle {
                    signalBarsView
                }
            }

            Spacer(minLength: 0)

            Button { resetWifi() } label: {
                HStack(spacing: 5) {
                    if resetState != .idle {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.55)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    Text(resetState.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(resetState == .idle ? .white : .white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(resetState == .idle ? .white.opacity(0.10) : .white.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            .disabled(resetState != .idle)
            .animation(.easeInOut(duration: 0.2), value: resetState)
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
        .onAppear {
            startMonitor()
            refreshCoreWLAN()
        }
        .onDisappear { monitor.cancel() }
        .onReceive(timer) { _ in
            if resetState == .idle || resetState == .reconnecting { refreshCoreWLAN() }
        }
    }

    private var signalBarsView: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(bar <= signalBars ? barColor : .white.opacity(0.12))
                    .frame(width: 5, height: CGFloat(4 + bar * 3))
                    .animation(.easeInOut(duration: 0.3).delay(Double(bar) * 0.05), value: signalBars)
            }
        }
        .frame(height: 18)
        .padding(.top, 2)
    }

    private var statusLabel: String {
        switch resetState {
        case .turningOff:   return "Turning off…"
        case .turningOn:    return "Turning on…"
        case .reconnecting: return "Reconnecting…"
        case .idle:
            if isConnected  { return "Connected" }
            if isWifiOn     { return "No network" }
            return "WiFi off"
        }
    }

    private var iconColor: Color {
        if resetState != .idle { return .white.opacity(0.35) }
        return isConnected ? .white : .white.opacity(0.30)
    }

    private var barColor: Color {
        switch signalBars {
        case 4: return .green
        case 3: return .mint
        case 2: return .yellow
        default: return .orange
        }
    }

    private func startMonitor() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isConnected = path.status == .satisfied
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }

    private func refreshCoreWLAN() {
        let iface = CWWiFiClient.shared().interface()
        isWifiOn = iface?.powerOn() ?? false
        ssid = iface?.ssid()
        signalBars = rssiToBars(iface?.rssiValue() ?? -100)
    }

    private func rssiToBars(_ rssi: Int) -> Int {
        if rssi >= -55 { return 4 }
        if rssi >= -65 { return 3 }
        if rssi >= -75 { return 2 }
        if rssi > -100 { return 1 }
        return 0
    }

    private func resetWifi() {
        guard resetState == .idle else { return }
        let iface = CWWiFiClient.shared().interface()

        withAnimation { resetState = .turningOff }
        DispatchQueue.global(qos: .userInitiated).async {
            try? iface?.setPower(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { resetState = .turningOn }
                DispatchQueue.global(qos: .userInitiated).async {
                    try? iface?.setPower(true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { resetState = .reconnecting }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation { resetState = .idle }
                            refreshCoreWLAN()
                        }
                    }
                }
            }
        }
    }
}
