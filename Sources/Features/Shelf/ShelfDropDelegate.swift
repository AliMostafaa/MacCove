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
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        shelf.addItem(from: url)
                    }
                }
            }
        }

        return true
    }
}
