import AppKit
import QuickLookThumbnailing
import LinkPresentation

@Observable
final class ShelfService {
    var items: [ShelfItem] = []

    private var metadataProviders: [UUID: LPMetadataProvider] = [:]

    func addItem(from url: URL) {
        guard !items.contains(where: { $0.url == url }) else { return }

        let item = ShelfItem(url: url)
        items.insert(item, at: 0)

        if item.isWebLink {
            fetchLinkMetadata(for: item)
        } else {
            generateThumbnail(for: url) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                        self.items[index].thumbnail = image
                    }
                }
            }
        }
    }

    /// Save a dropped image to disk then add as a shelf file item.
    func addImageItem(_ image: NSImage) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { return }

            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("MacCove/ShelfImages", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("\(UUID().uuidString).png")
            guard (try? png.write(to: file)) != nil else { return }

            DispatchQueue.main.async { self?.addItem(from: file) }
        }
    }

    func removeItem(_ item: ShelfItem) {
        metadataProviders[item.id] = nil
        items.removeAll { $0.id == item.id }
    }

    func clearAll() {
        metadataProviders.removeAll()
        items.removeAll()
    }

    func openItem(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func revealItem(_ item: ShelfItem) {
        guard !item.isWebLink else { return }
        NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
    }

    // MARK: - Private

    private func fetchLinkMetadata(for item: ShelfItem) {
        let provider = LPMetadataProvider()
        metadataProviders[item.id] = provider

        provider.startFetchingMetadata(for: item.url) { [weak self] metadata, error in
            guard let self, error == nil, let metadata else { return }

            DispatchQueue.main.async {
                guard let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                if let title = metadata.title, !title.isEmpty {
                    self.items[index].linkTitle = title
                }
            }

            metadata.iconProvider?.loadObject(ofClass: NSImage.self) { object, _ in
                guard let favicon = object as? NSImage else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                    self.items[index].thumbnail = favicon
                    self.metadataProviders[item.id] = nil
                }
            }
        }
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
                completion(NSWorkspace.shared.icon(forFile: url.path))
            }
        }
    }
}
