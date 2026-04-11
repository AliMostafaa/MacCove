import AppKit
import QuickLookThumbnailing

@Observable
final class ShelfService {
    var items: [ShelfItem] = []

    func addItem(from url: URL) {
        // Avoid duplicates
        guard !items.contains(where: { $0.url == url }) else { return }

        let item = ShelfItem(url: url)
        items.insert(item, at: 0)

        // Generate thumbnail asynchronously
        generateThumbnail(for: url) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    self.items[index].thumbnail = image
                }
            }
        }
    }

    func removeItem(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearAll() {
        items.removeAll()
    }

    func openItem(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func revealItem(_ item: ShelfItem) {
        NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
    }

    private func generateThumbnail(for url: URL, completion: @escaping (NSImage?) -> Void) {
        let size = CGSize(width: 120, height: 120)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, _, error in
            if let thumbnail {
                completion(thumbnail.nsImage)
            } else {
                // Fallback to file icon
                completion(NSWorkspace.shared.icon(forFile: url.path))
            }
        }
    }
}
