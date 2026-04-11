import AppKit
import UniformTypeIdentifiers

struct ShelfItem: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let fileType: UTType?
    var thumbnail: NSImage?
    let dateAdded: Date

    var isImage: Bool {
        fileType?.conforms(to: .image) ?? false
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    init(url: URL) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileType = UTType(filenameExtension: url.pathExtension)
        self.dateAdded = Date()
        self.thumbnail = nil
    }
}
