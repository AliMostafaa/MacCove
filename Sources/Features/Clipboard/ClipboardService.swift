import AppKit

struct ClipboardItem: Identifiable {
    let id = UUID()
    let text: String?
    let image: NSImage?
    let date: Date

    var isImage: Bool { image != nil }

    var preview: String {
        if let text {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(empty)" : trimmed
        }
        if let image {
            return "\(Int(image.size.width)) × \(Int(image.size.height))"
        }
        return "(unknown)"
    }

    var timeLabel: String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        return "\(Int(elapsed / 3600))h ago"
    }

    init(text: String, date: Date = Date()) {
        self.text = text
        self.image = nil
        self.date = date
    }

    init(image: NSImage, date: Date = Date()) {
        self.text = nil
        self.image = image
        self.date = date
    }
}

@Observable
final class ClipboardService {
    var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = -1

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
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

        // Images — check before text so a copied image isn't missed
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .tiff, .png,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic")
        ]
        if pb.availableType(from: imageTypes) != nil {
            let data = pb.data(forType: .tiff)
                ?? pb.data(forType: .png)
                ?? pb.data(forType: NSPasteboard.PasteboardType("public.jpeg"))
            if let data, !data.isEmpty, let image = NSImage(data: data) {
                items.insert(ClipboardItem(image: image), at: 0)
                if items.count > 15 { items.removeLast() }
                return
            }
        }

        // Text
        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if items.first?.text == text { return }
        items.insert(ClipboardItem(text: text), at: 0)
        if items.count > 15 { items.removeLast() }
    }

    func copy(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text = item.text {
            pb.setString(text, forType: .string)
        } else if let image = item.image, let tiff = image.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
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
