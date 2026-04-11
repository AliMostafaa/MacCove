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
    private var carbonEventHandler: EventHandlerRef?
    private var navigationEventTap: CFMachPort?
    private var navigationRunLoopSource: CFRunLoopSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        setupNotch()
        setupNowPlaying()
        setupClipboard()
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

        // Request Accessibility — enables CGEventTap for navigation key capture
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        // Register global hotkey via Carbon (works without Input Monitoring permission)
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
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { delegate.clipboardShortcutTriggered() }
                return noErr
            },
            1, &eventType, ptr, &carbonEventHandler
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x6D4E6F74), id: 1)
        // Shift+Cmd+V  (kVK_ANSI_V = 9)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &carbonHotKeyRef
        )
    }

    @objc private func clipboardShortcutTriggered() {
        // Capture which app the user was in before opening the notch
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        notchState.selectedClipboardIndex = 0
        notchState.currentPage = .clipboard
        notchState.isKeyboardPinned = true
        notchState.expand()
        windowController?.updateInteractivity()

        // Start a CGEventTap to intercept Up/Down/Enter/Esc without needing focus
        startNavigationEventTap()
    }

    // MARK: - CGEventTap for navigation

    private func startNavigationEventTap() {
        // Stop any existing tap first
        stopNavigationEventTap()

        let ptr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // Callback must be @convention(c) — no captures, context via userData
        let tapCallback: CGEventTapCallBack = { _, type, event, userData in
            guard let userData, type == .keyDown else {
                return Unmanaged.passRetained(event)
            }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let consumed = delegate.handleNavigationKey(keyCode: keyCode)
            return consumed ? nil : Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: ptr
        ) else {
            // Accessibility not granted yet — prompt happens at launch
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        navigationEventTap = tap
        navigationRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopNavigationEventTap() {
        if let tap = navigationEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = navigationRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        navigationEventTap = nil
        navigationRunLoopSource = nil
    }

    /// Called from the CGEventTap callback. Returns true if the key was consumed.
    @discardableResult
    private func handleNavigationKey(keyCode: Int) -> Bool {
        guard notchState.isExpanded, notchState.isKeyboardPinned,
              notchState.currentPage == .clipboard else { return false }

        let count = notchState.clipboard.items.count
        let navigationKeys = [125, 126, 36, 76, 53]
        guard navigationKeys.contains(keyCode) else { return false }

        DispatchQueue.main.async {
            switch keyCode {
            case 126: // Up arrow
                self.notchState.selectedClipboardIndex = max(self.notchState.selectedClipboardIndex - 1, 0)

            case 125: // Down arrow
                self.notchState.selectedClipboardIndex = min(self.notchState.selectedClipboardIndex + 1, max(count - 1, 0))

            case 36, 76: // Return / numpad Enter — copy + paste
                guard count > 0 else { return }
                let idx = self.notchState.selectedClipboardIndex
                guard idx < count else { return }
                self.notchState.clipboard.copy(self.notchState.clipboard.items[idx])
                self.dismissKeyboardClipboard()
                // Re-activate previous app, then simulate Cmd+V
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

            default:
                break
            }
        }

        return true // consume the event so it doesn't reach other apps
    }

    private func dismissKeyboardClipboard() {
        stopNavigationEventTap()
        notchState.isKeyboardPinned = false
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
