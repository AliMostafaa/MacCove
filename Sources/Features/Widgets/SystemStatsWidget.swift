import SwiftUI
import Darwin

struct SystemStatsWidget: View {
    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    @State private var memoryUsed: String = ""
    @State private var memoryTotal: String = ""
    @StateObject private var cpuMonitor = CPUMonitor()

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            GaugeRow(
                label: "CPU",
                value: cpuUsage,
                color: cpuUsage > 80 ? .red : cpuUsage > 50 ? .orange : NotchConstants.accentGlow
            )

            Divider()
                .overlay(Color.white.opacity(0.08))

            GaugeRow(
                label: "RAM",
                value: memoryUsage,
                color: memoryUsage > 80 ? .red : memoryUsage > 60 ? .orange : .green
            )

            if !memoryUsed.isEmpty {
                Text("\(memoryUsed) / \(memoryTotal)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
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
        .onAppear { updateStats() }
        .onReceive(timer) { _ in updateStats() }
    }

    private func updateStats() {
        cpuUsage = cpuMonitor.currentUsage()
        let (used, total) = getMemoryInfo()
        memoryUsage = total > 0 ? (used / total) * 100 : 0
        memoryUsed = formatBytes(used)
        memoryTotal = formatBytes(total)
    }

    private func getMemoryInfo() -> (used: Double, total: Double) {
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, totalMemory) }

        let pageSize = Double(vm_kernel_page_size)
        let appMemory = Double(vmStats.internal_page_count) * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize
        let wired = Double(vmStats.wire_count) * pageSize
        let usedMemory = appMemory + wired + compressed

        return (usedMemory, totalMemory)
    }

    private func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / 1_073_741_824
        if gb >= 10 {
            return String(format: "%.0f GB", gb)
        }
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - CPU Monitor (delta-based for real-time usage)

private final class CPUMonitor: ObservableObject {
    private var previousUser: Int64 = 0
    private var previousSystem: Int64 = 0
    private var previousIdle: Int64 = 0
    private var previousNice: Int64 = 0
    private var hasBaseline = false

    func currentUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else { return 0 }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: cpuInfo),
                          vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        var totalUser: Int64 = 0
        var totalSystem: Int64 = 0
        var totalIdle: Int64 = 0
        var totalNice: Int64 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += Int64(cpuInfo[offset + Int(CPU_STATE_USER)])
            totalSystem += Int64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += Int64(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            totalNice += Int64(cpuInfo[offset + Int(CPU_STATE_NICE)])
        }

        if !hasBaseline {
            // First sample — store baseline, return 0
            previousUser = totalUser
            previousSystem = totalSystem
            previousIdle = totalIdle
            previousNice = totalNice
            hasBaseline = true
            return 0
        }

        // Calculate delta since last sample
        let deltaUser = totalUser - previousUser
        let deltaSystem = totalSystem - previousSystem
        let deltaIdle = totalIdle - previousIdle
        let deltaNice = totalNice - previousNice

        previousUser = totalUser
        previousSystem = totalSystem
        previousIdle = totalIdle
        previousNice = totalNice

        let totalDelta = Double(deltaUser + deltaSystem + deltaIdle + deltaNice)
        guard totalDelta > 0 else { return 0 }

        let activeDelta = Double(deltaUser + deltaSystem + deltaNice)
        return min(activeDelta / totalDelta * 100, 100)
    }
}

// MARK: - Gauge Row

private struct GaugeRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(value / 100, 1.0))
                        .animation(.easeInOut(duration: 0.5), value: value)
                }
            }
            .frame(height: 6)
        }
    }
}
