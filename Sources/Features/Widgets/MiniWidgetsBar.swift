import SwiftUI
import IOKit
import IOKit.ps
import Network
import CoreWLAN

// MARK: - Bar

struct MiniWidgetsBar: View {
    @State private var time: String = ""
    @State private var batteryLevel: Int = 0
    @State private var isCharging: Bool = false
    @State private var isPluggedIn: Bool = false
    @State private var watts: Double = 0
    @State private var cpuUsage: Double = 0
    @State private var ramUsed: String = ""
    @State private var wifiConnected: Bool = false
    @State private var wifiName: String = ""

    @StateObject private var cpuMonitor = MiniCPUMonitor()
    private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Time
                MiniChip(
                    icon: "clock",
                    label: time,
                    color: .white.opacity(0.65)
                )

                // Battery
                MiniChip(
                    icon: batteryIcon,
                    label: batteryLabel,
                    color: batteryColor
                )

                // CPU
                MiniChip(
                    icon: "cpu",
                    label: String(format: "CPU %.0f%%", cpuUsage),
                    color: cpuUsage > 80 ? .red : cpuUsage > 50 ? .orange : .blue.opacity(0.9)
                )

                // RAM
                if !ramUsed.isEmpty {
                    MiniChip(
                        icon: "memorychip",
                        label: "RAM \(ramUsed)",
                        color: .purple.opacity(0.9)
                    )
                }

                // WiFi
                MiniChip(
                    icon: wifiConnected ? "wifi" : "wifi.slash",
                    label: wifiConnected ? (wifiName.isEmpty ? "Connected" : wifiName) : "No WiFi",
                    color: wifiConnected ? .green : .red.opacity(0.8)
                )
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            updateTime()
            updateBattery()
            updateSystem()
            startWifiMonitor()
        }
        .onReceive(timer) { _ in
            updateTime()
            updateBattery()
            updateSystem()
        }
    }

    // MARK: - Battery helpers

    private var batteryIcon: String {
        if isCharging          { return "bolt.fill" }
        if isPluggedIn         { return "powerplug" }
        if batteryLevel <= 10  { return "battery.0percent" }
        if batteryLevel <= 25  { return "battery.25percent" }
        if batteryLevel <= 50  { return "battery.50percent" }
        if batteryLevel <= 75  { return "battery.75percent" }
        return "battery.100percent"
    }

    private var batteryLabel: String {
        var parts = ["\(batteryLevel)%"]
        if isCharging && watts > 0.5 {
            parts.append("↑\(watts >= 10 ? String(format: "%.0fW", watts) : String(format: "%.1fW", watts))")
        } else if !isPluggedIn && watts > 0.5 {
            parts.append("↓\(watts >= 10 ? String(format: "%.0fW", watts) : String(format: "%.1fW", watts))")
        }
        return parts.joined(separator: " · ")
    }

    private var batteryColor: Color {
        if isCharging         { return .yellow }
        if batteryLevel <= 20 { return .red }
        if batteryLevel <= 40 { return .orange }
        return .green
    }

    // MARK: - Updates

    private func updateTime() {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        time = f.string(from: Date())
    }

    private func updateBattery() {
        // IOPowerSources for state
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources  = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
           let source   = sources.first,
           let info     = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
            batteryLevel = info[kIOPSCurrentCapacityKey] as? Int ?? batteryLevel
            isCharging   = info[kIOPSIsChargingKey]      as? Bool ?? false
            let state    = info[kIOPSPowerSourceStateKey] as? String ?? ""
            isPluggedIn  = state == kIOPSACPowerValue
        }

        // AppleSmartBattery for accurate watts
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard svc != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(svc) }

        func prop<T>(_ key: String) -> T? {
            IORegistryEntryCreateCFProperty(svc, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? T
        }
        let voltageMV: Int = prop("Voltage") ?? 0
        var rawAmp: Int    = prop("InstantAmperage") ?? 0
        if rawAmp == 0 { rawAmp = prop("Amperage") ?? 0 }
        if rawAmp > 2_000_000_000 { rawAmp -= 4_294_967_296 }
        watts = (voltageMV > 0 && rawAmp != 0)
            ? abs(Double(rawAmp) * Double(voltageMV)) / 1_000_000.0
            : 0
    }

    private func updateSystem() {
        cpuUsage = cpuMonitor.currentUsage()

        let total = Double(ProcessInfo.processInfo.physicalMemory)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        if result == KERN_SUCCESS {
            let page = Double(vm_kernel_page_size)
            let used = (Double(vmStats.internal_page_count) + Double(vmStats.wire_count) + Double(vmStats.compressor_page_count)) * page
            let gb = used / 1_073_741_824
            ramUsed = gb >= 10 ? String(format: "%.0f GB", gb) : String(format: "%.1f GB", gb)
            _ = total  // suppress warning
        }
    }

    private func startWifiMonitor() {
        pathMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                wifiConnected = path.status == .satisfied
                // SSID via CoreWLAN
                if let iface = CWWiFiClient.shared().interface() {
                    wifiName = iface.ssid() ?? ""
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .background))
    }
}

// MARK: - Chip

struct MiniChip: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.5))
        )
    }
}

// MARK: - Lightweight CPU monitor for bar

private final class MiniCPUMonitor: ObservableObject {
    private var prevUser: Int64 = 0
    private var prevSystem: Int64 = 0
    private var prevIdle: Int64 = 0
    private var prevNice: Int64 = 0
    private var ready = false

    func currentUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &cpuInfo, &numCPUInfo) == KERN_SUCCESS,
              let cpuInfo else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo),
                          vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        var u: Int64 = 0, s: Int64 = 0, id: Int64 = 0, n: Int64 = 0
        for i in 0..<Int(numCPUs) {
            let o = Int(CPU_STATE_MAX) * i
            u  += Int64(cpuInfo[o + Int(CPU_STATE_USER)])
            s  += Int64(cpuInfo[o + Int(CPU_STATE_SYSTEM)])
            id += Int64(cpuInfo[o + Int(CPU_STATE_IDLE)])
            n  += Int64(cpuInfo[o + Int(CPU_STATE_NICE)])
        }
        if !ready { prevUser = u; prevSystem = s; prevIdle = id; prevNice = n; ready = true; return 0 }
        let du = u - prevUser; let ds = s - prevSystem; let di = id - prevIdle; let dn = n - prevNice
        prevUser = u; prevSystem = s; prevIdle = id; prevNice = n
        let total = Double(du + ds + di + dn)
        return total > 0 ? min(Double(du + ds + dn) / total * 100, 100) : 0
    }
}
