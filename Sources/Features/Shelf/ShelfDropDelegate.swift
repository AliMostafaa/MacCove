import SwiftUI
import UniformTypeIdentifiers

struct ShelfDropDelegate: DropDelegate {
    let shelf: ShelfService
    @Binding var isDragHovering: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL, .url, .image])
    }

    func dropEntered(info: DropInfo) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDragHovering = true
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDragHovering = false
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        isDragHovering = false

        let providers = info.itemProviders(for: [.fileURL, .url, .image])

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                // File from Finder — use loadItem to get the original URL
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { shelf.addItem(from: url) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                // Web URL dragged from browser
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                    var resolved: URL?
                    if let url = data as? URL { resolved = url }
                    else if let d = data as? Data { resolved = URL(dataRepresentation: d, relativeTo: nil) }
                    else if let s = data as? String { resolved = URL(string: s) }
                    guard let url = resolved else { return }
                    DispatchQueue.main.async { shelf.addItem(from: url) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                // Image dragged directly from browser, Photos, Preview, etc.
                provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage else { return }
                    DispatchQueue.main.async { shelf.addImageItem(image) }
                }
            }
        }

        return true
    }
}
