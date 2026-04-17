import SwiftUI
import IOKit
import IOKit.ps
import Network
import CoreWLAN
import EventKit

// MARK: - Main View

struct DashboardView: View {
    @Environment(NotchState.self) private var state

    // Clock
    @State private var now = Date()
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    // Calendar
    @State private var displayMonth = Date()
    @State private var selectedDay: Int? = Calendar.current.component(.day, from: Date())

    // Battery
    @State private var batteryLevel: Int = 0
    @State private var isCharging: Bool = false
    @State private var isPluggedIn: Bool = false
    @State private var watts: Double = 0
    @State private var batteryTime: String = ""

    // System
    @State private var cpuUsage: Double = 0
    @State private var ramUsedGB: Double = 0
    @State private var ramTotalGB: Double = 0
    @StateObject private var cpuMon = DashCPUMonitor()

    // WiFi reset
    @State private var wifiResetState: WifiResetPhase = .idle

    // Expandable cards
    @State private var statsExpanded = false
    @State private var quickActionsExpanded = false

    // Calendar events
    private let eventStore = EKEventStore()
    @State private var dayEvents: [EKEvent] = []
    @State private var calendarAccess: Bool = false

    private let dataTimer = Timer.publish(every: 5, on: .main, in: .default).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            greetingBar
            Divider().overlay(Color.white.opacity(0.07))
            mainContent
        }
        .onAppear {
            // Defer all I/O until the opening animation settles (~500ms).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshData()
                let status = EKEventStore.authorizationStatus(for: .event)
                if status == .fullAccess {
                    calendarAccess = true
                    fetchEvents()
                } else {
                    requestCalendarAccess()
                }
            }
        }
        .onReceive(clockTimer) { newDate in
            guard state.isExpanded else { return }
            now = newDate
        }
        .onReceive(dataTimer) { _ in
            guard state.isExpanded else { return }
            refreshData()
        }
        .onChange(of: state.isExpanded) { _, expanded in
            if expanded {
                // Refresh data after animation settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    now = Date()
                    refreshData()
                }
            }
        }
        .onChange(of: selectedDay) { fetchEvents() }
        .onChange(of: displayMonth) { fetchEvents() }
    }

    // MARK: - Greeting Bar

    private var greetingBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(greetingText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Spacer()
            Text(formattedTime)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                // Removed .contentTransition(.numericText()) — it triggers a
                // ~200ms display-link animation every 1s clock tick, costing 8-15% CPU.
                // The time digits still update cleanly without animation.
        }
        .padding(.horizontal, 14)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 0) {
            calendarSection
                .padding(.trailing, 10)

            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(width: 1)
                .padding(.vertical, 2)

            rightSection
                .padding(.leading, 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(spacing: 7) {
            // Month navigation
            HStack(spacing: 4) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        displayMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayMonth)!
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(0.07)))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 0) {
                    Text(monthString)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(yearString)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        displayMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayMonth)!
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["Su","Mo","Tu","We","Th","Fr","Sa"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: cols, spacing: 3) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { item in
                    if let day = item.element {
                        let isToday    = isCurrentMonth && day == todayDay
                        let isSelected = selectedDay == day && isCurrentMonth
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                selectedDay = (selectedDay == day) ? nil : day
                            }
                        } label: {
                            Text("\(day)")
                                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                                .foregroundStyle(
                                    isToday    ? .black :
                                    isSelected ? .white :
                                    .white.opacity(0.72)
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 19)
                                .background {
                                    if isToday {
                                        Circle().fill(NotchConstants.accentGlow)
                                    } else if isSelected {
                                        Circle().fill(.white.opacity(0.15))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 19)
                    }
                }
            }

            if !isCurrentMonth {
                Button {
                    withAnimation(.spring(response: 0.3)) { displayMonth = Date() }
                } label: {
                    Text("Today")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(NotchConstants.accentGlow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(NotchConstants.accentGlow.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            // ── Events panel ───────────────────────────────────────────────
            if selectedDay != nil {
                Divider()
                    .overlay(Color.white.opacity(0.10))
                    .padding(.vertical, 3)

                if !calendarAccess {
                    Button {
                        requestCalendarAccess()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 14))
                                .foregroundStyle(NotchConstants.accentGlow.opacity(0.7))
                            Text("Allow Calendar")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                } else if dayEvents.isEmpty {
                    VStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.18))
                        Text("No events")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                } else {
                    // Show up to 4 events, then "+N more" label
                    let maxVisible = 4
                    let visible = Array(dayEvents.prefix(maxVisible))
                    let remaining = dayEvents.count - maxVisible

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(visible, id: \.eventIdentifier) { event in
                            CalendarEventRow(event: event)
                        }
                        if remaining > 0 {
                            Text("+\(remaining) more")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(NotchConstants.accentGlow.opacity(0.6))
                                .padding(.top, 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 168)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    // MARK: - Right Section

    private var rightSection: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                batteryCard.frame(maxWidth: 84)
                systemCard.frame(maxWidth: .infinity)
                quickActionsCard.frame(maxWidth: .infinity)
            }
            .frame(height: 100)

            nowPlayingCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Battery Card

    private var batteryCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Icon + label
            HStack(spacing: 3) {
                Image(systemName: isCharging ? "bolt.fill" : "battery.100percent")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(isCharging ? .yellow : batteryLevelColor)
                Text("Battery")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Level
            Text("\(batteryLevel)%")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(batteryLevelColor)
                .monospacedDigit()

            // Status
            Group {
                if isCharging {
                    Text(watts > 0.5 ? String(format: "↑%.0fW", watts) : "Charging")
                        .foregroundStyle(.yellow.opacity(0.85))
                } else if isPluggedIn {
                    Text("Plugged In").foregroundStyle(.white.opacity(0.45))
                } else {
                    Text(watts > 0.5 ? String(format: "↓%.0fW", watts) : "Battery")
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .font(.system(size: 8, weight: .medium))

            if !batteryTime.isEmpty {
                Text(batteryTime)
                    .font(.system(size: 7))
                    .foregroundStyle(.white.opacity(0.28))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - System Card

    private var systemCard: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                statsExpanded.toggle()
                if statsExpanded { updateSystem() }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(statsExpanded ? NotchConstants.accentGlow : .white.opacity(0.4))
                    Text("System")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Image(systemName: statsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.25))
                }

                if statsExpanded {
                    VStack(spacing: 8) {
                        DashGauge(label: "CPU", value: cpuUsage,
                                  color: cpuUsage > 80 ? .red : cpuUsage > 50 ? .orange : NotchConstants.accentGlow)
                        DashGauge(label: "RAM",
                                  value: ramTotalGB > 0 ? (ramUsedGB / ramTotalGB * 100) : 0,
                                  color: .purple.opacity(0.9),
                                  valueLabel: ramTotalGB > 0 ? String(format: "%.1f/%.0fG", ramUsedGB, ramTotalGB) : nil)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    // Inactive hint
                    Text("Tap to view")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.2))
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cardBG)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Now Playing Card

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(state.nowPlaying.isPlaying ? NotchConstants.accentGlow : .white.opacity(0.4))
                Text("Now Playing")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if state.nowPlaying.hasTrack {
                // Artwork + track info
                HStack(alignment: .center, spacing: 8) {
                    Group {
                        if let artwork = state.nowPlaying.artwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(.white.opacity(0.08))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.3))
                                )
                        }
                    }
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.nowPlaying.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(state.nowPlaying.artist)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }

                // Seek bar — always visible with times
                DashSeekBar(
                    progress: state.nowPlaying.progress,
                    duration: state.nowPlaying.duration
                )

                // Playback controls
                HStack(spacing: 0) {
                    Spacer()
                    Button {
                        NotificationCenter.default.post(name: .init("MacCove.previousTrack"), object: nil)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 32, height: 20)
                    }
                    .buttonStyle(.plain)

                    Button {
                        NotificationCenter.default.post(name: .init("MacCove.togglePlayPause"), object: nil)
                    } label: {
                        Image(systemName: state.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 20)
                    }
                    .buttonStyle(.plain)

                    Button {
                        NotificationCenter.default.post(name: .init("MacCove.nextTrack"), object: nil)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 32, height: 20)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                Spacer(minLength: 0)

            } else {
                // Empty state — centred placeholder
                VStack(spacing: 5) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.1))
                    Text("Nothing playing")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.22))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick Actions Card

    private var quickActionsCard: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                quickActionsExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(quickActionsExpanded ? .yellow.opacity(0.8) : .white.opacity(0.4))
                    Text("Quick Open")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Image(systemName: quickActionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.25))
                }

                if quickActionsExpanded {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            DashActionButton(icon: "folder.fill", label: "Finder", compact: true) {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
                            }
                            DashActionButton(icon: "gear", label: "Settings", compact: true) {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
                            }
                        }
                        HStack(spacing: 4) {
                            DashActionButton(icon: "terminal.fill", label: "Terminal", compact: true) {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                            }
                            DashActionButton(icon: "chart.bar.fill", label: "Activity", compact: true) {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                            }
                        }
                        HStack(spacing: 4) {
                            // WiFi Reset
                            Button { resetWifi() } label: {
                                HStack(spacing: 5) {
                                    if wifiResetState != .idle {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.5)
                                            .frame(width: 10, height: 10)
                                    } else {
                                        Image(systemName: "wifi.router")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    Text(wifiResetState.label)
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundStyle(wifiResetState == .idle ? .white.opacity(0.6) : .white.opacity(0.35))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(wifiResetState == .idle ? .white.opacity(0.07) : .white.opacity(0.04)))
                            }
                            .buttonStyle(.plain)
                            .disabled(wifiResetState != .idle)
                            .animation(.easeInOut(duration: 0.2), value: wifiResetState)

                            // Minimize to dot
                            Button { state.minimize() } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(.white.opacity(0.07)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text("Tap to open")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.2))
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cardBG)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared

    private var cardBG: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
    }

    private var batteryLevelColor: Color {
        isCharging ? .yellow :
        batteryLevel <= 20 ? .red :
        batteryLevel <= 40 ? .orange : .green
    }

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: now)
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    // Cached formatters — avoid allocating a new DateFormatter every second
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f
    }()
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f
    }()

    private var formattedTime: String { Self.timeFmt.string(from: now) }
    private var formattedDate: String { Self.dateFmt.string(from: now) }

    // MARK: - Calendar helpers

    private var calendarDays: [Int?] {
        let cal = Calendar.current
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth)),
              let range = cal.range(of: .day, in: .month, for: displayMonth) else { return [] }
        let offset = cal.component(.weekday, from: first) - 1
        var days: [Int?] = Array(repeating: nil, count: offset)
        days += (1...range.count).map { Optional($0) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month], from: displayMonth)
        let t = cal.dateComponents([.year, .month], from: Date())
        return d.year == t.year && d.month == t.month
    }

    private var todayDay: Int { Calendar.current.component(.day, from: Date()) }

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f
    }()
    private static let yearFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy"; return f
    }()

    private var monthString: String { Self.monthFmt.string(from: displayMonth) }
    private var yearString: String { Self.yearFmt.string(from: displayMonth) }

    // MARK: - Data

    /// Runs battery + system queries off the main thread, then posts results back.
    /// Prevents IOKit / host_statistics64 syscalls from blocking SwiftUI's render loop.
    private func refreshData() {
        let needsSystem = statsExpanded
        let mon = cpuMon
        DispatchQueue.global(qos: .userInitiated).async {
            // Battery
            var bl = 0, wt = 0.0, ic = false, ip = false, bt = ""
            if let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
               let srcs = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [Any],
               let src  = srcs.first,
               let info = IOPSGetPowerSourceDescription(snap, src as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
                bl = info[kIOPSCurrentCapacityKey] as? Int  ?? 0
                ic = info[kIOPSIsChargingKey]      as? Bool ?? false
                ip = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            }
            let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            if svc != IO_OBJECT_NULL {
                defer { IOObjectRelease(svc) }
                func p<T>(_ k: String) -> T? {
                    IORegistryEntryCreateCFProperty(svc, k as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? T
                }
                let v: Int = p("Voltage") ?? 0
                var a: Int = p("InstantAmperage") ?? 0
                if a == 0 { a = p("Amperage") ?? 0 }
                if a > 2_000_000_000 { a -= 4_294_967_296 }
                wt = (v > 0 && a != 0) ? abs(Double(a) * Double(v)) / 1_000_000.0 : 0
                if !ip {
                    let t: Int = p("TimeRemaining") ?? 0
                    let mins = (t > 0 && t < 65535) ? t : (p("AvgTimeToEmpty") ?? 0)
                    if mins > 0 && mins < 65535 {
                        let h = mins / 60, m = mins % 60
                        bt = h > 0 ? "\(h)h \(m)m left" : "\(m)m left"
                    }
                } else if ic {
                    let mins: Int = p("AvgTimeToFull") ?? 0
                    if mins > 0 && mins < 65535 {
                        let h = mins / 60, m = mins % 60
                        bt = h > 0 ? "\(h)h \(m)m to full" : "\(m)m to full"
                    }
                }
            }
            // System stats
            var cu = 0.0, ruGB = 0.0, rtGB = 0.0
            if needsSystem {
                cu = mon.currentUsage()
                rtGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
                var vm  = vm_statistics64()
                var cnt = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
                let r   = withUnsafeMutablePointer(to: &vm) { ptr in
                    ptr.withMemoryRebound(to: integer_t.self, capacity: Int(cnt)) {
                        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &cnt)
                    }
                }
                if r == KERN_SUCCESS {
                    let page = Double(vm_kernel_page_size)
                    ruGB = (Double(vm.internal_page_count) + Double(vm.wire_count) + Double(vm.compressor_page_count)) * page / 1_073_741_824
                }
            }
            DispatchQueue.main.async {
                batteryLevel = bl
                isCharging = ic
                isPluggedIn = ip
                watts = wt
                batteryTime = bt
                if needsSystem {
                    cpuUsage = cu
                    ramTotalGB = rtGB
                    ramUsedGB = ruGB
                }
            }
        }
    }

    private func updateBattery() {
        if let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let srcs = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [Any],
           let src  = srcs.first,
           let info = IOPSGetPowerSourceDescription(snap, src as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
            batteryLevel = info[kIOPSCurrentCapacityKey] as? Int  ?? batteryLevel
            isCharging   = info[kIOPSIsChargingKey]      as? Bool ?? false
            isPluggedIn  = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        }
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard svc != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(svc) }
        func p<T>(_ k: String) -> T? {
            IORegistryEntryCreateCFProperty(svc, k as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? T
        }
        let v: Int = p("Voltage") ?? 0
        var a: Int = p("InstantAmperage") ?? 0
        if a == 0 { a = p("Amperage") ?? 0 }
        if a > 2_000_000_000 { a -= 4_294_967_296 }
        watts = (v > 0 && a != 0) ? abs(Double(a) * Double(v)) / 1_000_000.0 : 0

        batteryTime = ""
        if !isPluggedIn {
            let t: Int = p("TimeRemaining") ?? 0
            let mins = (t > 0 && t < 65535) ? t : (p("AvgTimeToEmpty") ?? 0)
            if mins > 0 && mins < 65535 {
                let h = mins / 60, m = mins % 60
                batteryTime = h > 0 ? "\(h)h \(m)m left" : "\(m)m left"
            }
        } else if isCharging {
            let mins: Int = p("AvgTimeToFull") ?? 0
            if mins > 0 && mins < 65535 {
                let h = mins / 60, m = mins % 60
                batteryTime = h > 0 ? "\(h)h \(m)m to full" : "\(m)m to full"
            }
        }
    }

    private func updateSystem() {
        cpuUsage = cpuMon.currentUsage()
        ramTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        var vm  = vm_statistics64()
        var cnt = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let r   = withUnsafeMutablePointer(to: &vm) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(cnt)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &cnt)
            }
        }
        if r == KERN_SUCCESS {
            let page = Double(vm_kernel_page_size)
            ramUsedGB = (Double(vm.internal_page_count) + Double(vm.wire_count) + Double(vm.compressor_page_count)) * page / 1_073_741_824
        }
    }

    private func requestCalendarAccess() {
        Task {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    calendarAccess = granted
                    if granted { fetchEvents() }
                }
            } catch {
                await MainActor.run { calendarAccess = false }
            }
        }
    }

    private func fetchEvents() {
        guard calendarAccess, let day = selectedDay else {
            dayEvents = []
            return
        }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: displayMonth)
        comps.day = day
        guard let date = cal.date(from: comps) else { return }
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        dayEvents = eventStore.events(matching: predicate)
            .sorted { $0.isAllDay != $1.isAllDay ? $0.isAllDay : $0.startDate < $1.startDate }
    }

    private func resetWifi() {
        guard wifiResetState == .idle else { return }
        let iface = CWWiFiClient.shared().interface()
        withAnimation { wifiResetState = .turningOff }
        DispatchQueue.global(qos: .userInitiated).async {
            try? iface?.setPower(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { wifiResetState = .turningOn }
                DispatchQueue.global(qos: .userInitiated).async {
                    try? iface?.setPower(true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { wifiResetState = .reconnecting }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation { wifiResetState = .idle }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - WiFi Reset Phase

enum WifiResetPhase: Equatable {
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

// MARK: - Gauge

private struct DashGauge: View {
    let label: String
    let value: Double
    let color: Color
    var valueLabel: String? = nil

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text(valueLabel ?? String(format: "%.0f%%", value))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            Capsule().fill(.white.opacity(0.08))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(
                            width: nil,   // determined by scaleEffect below
                            height: 4
                        )
                        .scaleEffect(x: min(max(value / 100, 0), 1), y: 1, anchor: .leading)
                        .animation(.easeInOut(duration: 0.5), value: value)
                }
        }
    }
}

// MARK: - Action Button

private struct DashActionButton: View {
    let icon: String
    let label: String
    var compact: Bool = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 8 : 9, weight: .semibold))
                Text(label)
                    .font(.system(size: compact ? 8 : 9, weight: .medium))
            }
            .foregroundStyle(hovered ? .white : .white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 3 : 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovered ? .white.opacity(0.13) : .white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Calendar Event Row

private struct CalendarEventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            // Calendar color pill
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 3, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Text(event.isAllDay ? "All day" : timeLabel)
                    .font(.system(size: 7.5))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.04)))
    }

    private static let eventTimeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var timeLabel: String {
        let start = Self.eventTimeFmt.string(from: event.startDate)
        let end   = Self.eventTimeFmt.string(from: event.endDate)
        return "\(start) – \(end)"
    }
}

// MARK: - Seek Bar

private struct DashSeekBar: View {
    let progress: Double
    let duration: TimeInterval

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var displayProgress: Double { isDragging ? dragProgress : progress }

    private func formattedTime(_ t: TimeInterval) -> String {
        let t = max(0, t)
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func seek(to p: Double) {
        NotificationCenter.default.post(
            name: .init("MacCove.seekTo"),
            object: nil,
            userInfo: ["time": p * duration]
        )
    }

    var body: some View {
        VStack(spacing: 4) {
            // Track — uses scaleEffect instead of GeometryReader to avoid
            // double layout passes on every 1-second progress update.
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule()
                    .fill(NotchConstants.accentGlow.opacity(isDragging ? 1.0 : 0.75))
                    .scaleEffect(x: max(0.001, displayProgress), y: 1, anchor: .leading)
                    .animation(isDragging ? nil : .linear(duration: 0.15), value: displayProgress)
                // Thumb — positioned via offset (not alignmentGuide, which would
                // expand the ZStack's layout size at the edges)
                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .offset(x: trackWidth * displayProgress - 4)
                    .animation(isDragging ? nil : .linear(duration: 0.15), value: displayProgress)
            }
            .frame(height: 4)
            .frame(maxHeight: 10)
            .clipped()
            .contentShape(Rectangle())
            .coordinateSpace(name: "seekTrack")
            .onTapGesture { location in
                let p = max(0, min(location.x / trackWidth, 1))
                seek(to: p)
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("seekTrack"))
                    .onChanged { value in
                        isDragging = true
                        dragProgress = max(0, min(value.location.x / trackWidth, 1))
                    }
                    .onEnded { value in
                        seek(to: max(0, min(value.location.x / trackWidth, 1)))
                        isDragging = false
                    }
            )

            // Time labels
            HStack {
                Text(formattedTime(displayProgress * duration))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(formattedTime(duration))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
    }

    // The seek bar lives inside the nowPlayingCard which fills the right
    // section. The track width is predictable from the layout constants.
    private var trackWidth: CGFloat {
        // rightSection width ≈ expandedWidth - calendarWidth(168) - divider(1) - paddings
        // nowPlayingCard has 10px padding on each side
        let rightW = NotchConstants.expandedWidth - 32 - 168 - 1 - 10 - 10 - 12 - 12
        return max(rightW - 20, 100)  // 20 for inner padding
    }
}

// MARK: - CPU Monitor

private final class DashCPUMonitor: ObservableObject {
    private var pU: Int64 = 0, pS: Int64 = 0, pI: Int64 = 0, pN: Int64 = 0
    private var ready = false

    func currentUsage() -> Double {
        var ci: processor_info_array_t?
        var nc: mach_msg_type_number_t = 0
        var nCPUs: natural_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &nCPUs, &ci, &nc) == KERN_SUCCESS, let ci else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: ci),
                          vm_size_t(nc) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        var u: Int64 = 0, s: Int64 = 0, i: Int64 = 0, n: Int64 = 0
        for k in 0..<Int(nCPUs) {
            let o = Int(CPU_STATE_MAX) * k
            u += Int64(ci[o + Int(CPU_STATE_USER)])
            s += Int64(ci[o + Int(CPU_STATE_SYSTEM)])
            i += Int64(ci[o + Int(CPU_STATE_IDLE)])
            n += Int64(ci[o + Int(CPU_STATE_NICE)])
        }
        if !ready { pU = u; pS = s; pI = i; pN = n; ready = true; return 0 }
        let du = u-pU, ds = s-pS, di = i-pI, dn = n-pN
        pU = u; pS = s; pI = i; pN = n
        let total = Double(du+ds+di+dn)
        return total > 0 ? min(Double(du+ds+dn) / total * 100, 100) : 0
    }
}
