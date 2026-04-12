import AppKit
import UniformTypeIdentifiers

struct ShelfItem: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let fileType: UTType?
    var thumbnail: NSImage?
    var linkTitle: String?
    let fileSize: String?
    let fileExtensionLabel: String?
    let dateAdded: Date

    var isWebLink: Bool {
        url.scheme == "http" || url.scheme == "https"
    }

    var isImage: Bool {
        fileType?.conforms(to: .image) ?? false
    }

    var displayName: String {
        if isWebLink { return linkTitle ?? linkDomain ?? url.host ?? url.absoluteString }
        return fileName
    }

    var linkDomain: String? {
        guard let host = url.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var icon: NSImage {
        if isWebLink {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
                ?? NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    init(url: URL) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileType = UTType(filenameExtension: url.pathExtension)
        self.dateAdded = Date()
        self.thumbnail = nil
        self.linkTitle = nil

        // File metadata (skip for web links)
        let isWeb = url.scheme == "http" || url.scheme == "https"
        if !isWeb, let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]) {
            if let size = resourceValues.fileSize {
                self.fileSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            } else {
                self.fileSize = nil
            }
        } else {
            self.fileSize = nil
        }

        let ext = url.pathExtension.uppercased()
        self.fileExtensionLabel = (!isWeb && !ext.isEmpty) ? ext : nil
    }
}
