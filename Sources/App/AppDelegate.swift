import AppKit
import SwiftUI
import Carbon.HIToolbox
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    let notchState = NotchState()

    private var statusItem: NSStatusItem!
    private var windowController: NotchWindowController?
    private var hoverMonitor: HoverMonitor?
    private var nowPlayingService: NowPlayingService?

    // Clipboard shortcut state
    private var previousFrontmostApp: NSRunningApplication?
    private var carbonHotKeyRef: EventHotKeyRef?
    private var bracketLeftRef: EventHotKeyRef?
    private var bracketRightRef: EventHotKeyRef?
    private var hyperkeyNRef: EventHotKeyRef?
    private var carbonEventHandler: EventHandlerRef?
    private var navigationEventTap: CFMachPort?
    private var navigationRunLoopSource: CFRunLoopSource?

    // Page navigation via scroll/swipe
    private var scrollWheelMonitor: Any?
    private var lastPageNavigationTime: TimeInterval = 0
    private var scrollAccumulator: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        setupNotch()
        setupNowPlaying()
        setupClipboard()
        setupPageNavigation()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "MacCove")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Notch", action: #selector(toggleNotch), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MacCove", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Notch Setup

    private func setupNotch() {
        let detector = NotchDetector()
        notchState.hasNotch = detector.hasNotch()
        notchState.notchRect = detector.notchRect()
        notchState.screenWithNotch = detector.screenWithNotch()

        windowController = NotchWindowController(state: notchState)
        windowController?.showWindow()

        hoverMonitor = HoverMonitor(state: notchState, windowController: windowController!)
        hoverMonitor?.start()

        NotificationCenter.default.addObserver(
            forName: .init("MacCove.notchPositionChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.windowController?.repositionPanel()
        }
    }

    // MARK: - Now Playing

    private func setupNowPlaying() {
        nowPlayingService = NowPlayingService(model: notchState.nowPlaying)
        nowPlayingService?.start()

        NotificationCenter.default.addObserver(forName: .init("MacCove.togglePlayPause"), object: nil, queue: .main) { [weak self] _ in
            self?.nowPlayingService?.togglePlayPause()
        }
        NotificationCenter.default.addObserver(forName: .init("MacCove.nextTrack"), object: nil, queue: .main) { [weak self] _ in
            self?.nowPlayingService?.nextTrack()
        }
        NotificationCenter.default.addObserver(forName: .init("MacCove.previousTrack"), object: nil, queue: .main) { [weak self] _ in
            self?.nowPlayingService?.previousTrack()
        }
        NotificationCenter.default.addObserver(forName: .init("MacCove.seekTo"), object: nil, queue: .main) { [weak self] notification in
            if let time = notification.userInfo?["time"] as? TimeInterval {
                self?.nowPlayingService?.seekTo(time: time)
            }
        }
    }

    // MARK: - Clipboard

    private func setupClipboard() {
        notchState.clipboard.start()

        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        registerCarbonHotKey()
    }

    private func registerCarbonHotKey() {
        let ptr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData, let event else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                switch hkID.id {
                case 1: DispatchQueue.main.async { delegate.clipboardShortcutTriggered() }
                case 2: DispatchQueue.main.async { delegate.navigatePage(by: -1) }
                case 3: DispatchQueue.main.async { delegate.navigatePage(by: +1) }
                case 4: DispatchQueue.main.async { delegate.toggleNotch() }
                default: break
                }
                return noErr
            },
            1, &eventType, ptr, &carbonEventHandler
        )

        let sig = OSType(0x6D4E6F74)
        // id:1  Shift+Cmd+V — clipboard
        RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey),
                            EventHotKeyID(signature: sig, id: 1),
                            GetApplicationEventTarget(), 0, &carbonHotKeyRef)
        // id:2  Cmd+[  — previous page
        RegisterEventHotKey(UInt32(kVK_ANSI_LeftBracket), UInt32(cmdKey),
                            EventHotKeyID(signature: sig, id: 2),
                            GetApplicationEventTarget(), 0, &bracketLeftRef)
        // id:3  Cmd+]  — next page
        RegisterEventHotKey(UInt32(kVK_ANSI_RightBracket), UInt32(cmdKey),
                            EventHotKeyID(signature: sig, id: 3),
                            GetApplicationEventTarget(), 0, &bracketRightRef)
        // id:4  Hyperkey+N (Cmd+Ctrl+Opt+Shift+N) — toggle notch
        RegisterEventHotKey(UInt32(kVK_ANSI_N),
                            UInt32(cmdKey | shiftKey | optionKey | controlKey),
                            EventHotKeyID(signature: sig, id: 4),
                            GetApplicationEventTarget(), 0, &hyperkeyNRef)
    }

    @objc private func clipboardShortcutTriggered() {
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        notchState.selectedClipboardIndex = 0
        notchState.clipboardSearchQuery = ""
        notchState.isClipboardSearchActive = true
        notchState.currentPage = .clipboard
        notchState.isKeyboardPinned = true
        notchState.expand()
        windowController?.updateInteractivity()

        startNavigationEventTap()
    }

    // MARK: - CGEventTap

    private func startNavigationEventTap() {
        stopNavigationEventTap()

        let ptr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        let tapCallback: CGEventTapCallBack = { _, type, event, userData in
            guard let userData, type == .keyDown else {
                return Unmanaged.passRetained(event)
            }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            var uniLength = 0
            var uniChars = [UniChar](repeating: 0, count: 4)
            event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &uniLength, unicodeString: &uniChars)
            let typedChar: String? = uniLength > 0
                ? String(utf16CodeUnits: Array(uniChars.prefix(uniLength)), count: uniLength)
                : nil

            let consumed = delegate.handleNavigationKey(keyCode: keyCode, flags: flags, typedChar: typedChar)
            return consumed ? nil : Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: ptr
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        navigationEventTap = tap
        navigationRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopNavigationEventTap() {
        if let tap = navigationEventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = navigationRunLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        navigationEventTap = nil
        navigationRunLoopSource = nil
    }

    @discardableResult
    private func handleNavigationKey(keyCode: Int, flags: CGEventFlags, typedChar: String?) -> Bool {
        guard notchState.isExpanded, notchState.isKeyboardPinned,
              notchState.currentPage == .clipboard else { return false }

        // Let Cmd/Ctrl shortcuts pass through
        if flags.contains(.maskCommand) || flags.contains(.maskControl) { return false }

        DispatchQueue.main.async {
            let items = self.notchState.filteredClipboardItems
            let count = items.count

            switch keyCode {
            case 126: // Up
                self.notchState.selectedClipboardIndex = max(self.notchState.selectedClipboardIndex - 1, 0)

            case 125: // Down
                self.notchState.selectedClipboardIndex = min(self.notchState.selectedClipboardIndex + 1, max(count - 1, 0))

            case 36, 76: // Enter — copy + paste
                guard count > 0 else { return }
                let idx = self.notchState.selectedClipboardIndex
                guard idx < count else { return }
                self.notchState.clipboard.copy(items[idx])
                self.dismissKeyboardClipboard()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.previousFrontmostApp?.activate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        self.simulatePaste()
                    }
                }

            case 53: // Escape
                self.dismissKeyboardClipboard()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.previousFrontmostApp?.activate()
                }

            case 51: // Delete/Backspace
                if !self.notchState.clipboardSearchQuery.isEmpty {
                    self.notchState.clipboardSearchQuery.removeLast()
                    self.notchState.selectedClipboardIndex = 0
                }

            default:
                // Printable character → append to search query
                guard let char = typedChar,
                      char.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else { return }
                self.notchState.clipboardSearchQuery += char
                self.notchState.selectedClipboardIndex = 0
            }
        }

        return true
    }

    private func dismissKeyboardClipboard() {
        stopNavigationEventTap()
        notchState.isKeyboardPinned = false
        notchState.isClipboardSearchActive = false
        notchState.clipboardSearchQuery = ""
        notchState.collapse()
        windowController?.updateInteractivity()
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - Page Navigation

    private func setupPageNavigation() {
        scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollWheel(event)
            return event
        }
    }

    private func handleScrollWheel(_ event: NSEvent) {
        guard notchState.isExpanded else { return }

        let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY * 10
        guard abs(delta) > 1 else { return }

        scrollAccumulator += delta

        let threshold: CGFloat = 40
        guard abs(scrollAccumulator) >= threshold else { return }

        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastPageNavigationTime > 0.35 else {
            scrollAccumulator = 0
            return
        }
        lastPageNavigationTime = now
        let direction = scrollAccumulator > 0 ? -1 : 1
        scrollAccumulator = 0
        navigatePage(by: direction)
    }

    private func navigatePage(by direction: Int) {
        guard notchState.isExpanded else { return }
        let pages = NotchPage.allCases
        guard let current = pages.firstIndex(of: notchState.currentPage) else { return }
        let next = (current + direction + pages.count) % pages.count
        withAnimation(NotchConstants.tabSpring) {
            notchState.currentPage = pages[next]
        }
    }

    // MARK: - Actions

    @objc private func toggleNotch() {
        notchState.toggle()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
