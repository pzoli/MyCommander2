import Foundation

enum FileCategory {
    case directory
    case parentDirectory
    case executable
    case archive
    case image
    case document
    case symlink
    case regular
}

struct FileItem: Identifiable, Hashable {
    var id: String {
        if isParentDir {
            return "\(url.path)/__mc_parent__"
        }
        return url.path
    }
    
    let name: String
    let url: URL
    let isDirectory: Bool
    let isExecutable: Bool
    let isSymlink: Bool
    let size: Int64
    let modificationDate: Date
    let category: FileCategory
    let isParentDir: Bool
    
    static func parentDirectory(for currentURL: URL) -> FileItem {
        let parentURL = currentURL.deletingLastPathComponent().standardizedFileURL
        return FileItem(
            name: "/..",
            url: parentURL,
            isDirectory: true,
            isExecutable: false,
            isSymlink: false,
            size: 0,
            modificationDate: Date.distantPast,
            category: .parentDirectory,
            isParentDir: true
        )
    }
}

enum SortField: String, CaseIterable, Identifiable {
    case name = "Name"
    case size = "Size"
    case date = "Modify time"
    
    var id: String { rawValue }
}

enum SortOrder {
    case ascending
    case descending
    
    mutating func toggle() {
        self = (self == .ascending) ? .descending : .ascending
    }
}

enum PanelSide: String {
    case left = "Left"
    case right = "Right"
}
