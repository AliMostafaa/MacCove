import AppKit

struct ClipboardItem: Identifiable {
    let id = UUID()
    let text: String
    let date: Date

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(empty)" : trimmed
    }

    var timeLabel: String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        return "\(Int(elapsed / 3600))h ago"
    }
}

@Observable
final class ClipboardService {
    var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = -1

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Don't add duplicate of the most recent entry
        if items.first?.text == text { return }

        let item = ClipboardItem(text: text, date: Date())
        items.insert(item, at: 0)
        if items.count > 15 { items.removeLast() }
    }

    func copy(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        // Update lastChangeCount so we don't re-add what we just set
        lastChangeCount = pb.changeCount
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }

    deinit { stop() }
}
