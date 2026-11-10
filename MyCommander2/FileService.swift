import Foundation
import SwiftUI

/// Fájlrendszer műveletek és formázás segédosztály
class FileService {
    static let shared = FileService()
    
    private let fileManager = FileManager.default
    
    var defaultDirectory: URL {
        return fileManager.homeDirectoryForCurrentUser
    }
    
    /// Könyvtár tartalmának betöltése
    func loadDirectory(at url: URL, showHidden: Bool = false) -> [FileItem] {
        var items: [FileItem] = []
        let standardURL = url.standardizedFileURL
        
        // Szülőkönyvtár hozzáadása (/..), ha nem a gyökérkönyvtárban vagyunk
        if standardURL.path != "/" {
            items.append(FileItem.parentDirectory(for: standardURL))
        }
        
        let keys: [URLResourceKey] = [
            .nameKey,
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isExecutableKey,
            .isHiddenKey
        ]
        
        do {
            let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
            let contents = try fileManager.contentsOfDirectory(at: standardURL, includingPropertiesForKeys: keys, options: options)
            
            for fileURL in contents {
                let standardItemURL = fileURL.standardizedFileURL
                let resourceValues = try? standardItemURL.resourceValues(forKeys: Set(keys))
                
                let name = fileURL.lastPathComponent
                if !showHidden && name.hasPrefix(".") {
                    continue
                }
                
                var isDirectory = resourceValues?.isDirectory ?? false
                if !isDirectory {
                    var isDirObjC: ObjCBool = false
                    if fileManager.fileExists(atPath: standardItemURL.path, isDirectory: &isDirObjC) {
                        isDirectory = isDirObjC.boolValue
                    }
                }
                
                let size = Int64(resourceValues?.fileSize ?? 0)
                let date = resourceValues?.contentModificationDate ?? Date.distantPast
                let isExecutable = resourceValues?.isExecutable ?? false
                let isSymlink = resourceValues?.isSymbolicLink ?? false
                
                let category = determineCategory(url: standardItemURL, isDirectory: isDirectory, isExecutable: isExecutable, isSymlink: isSymlink)
                
                let item = FileItem(
                    name: name,
                    url: standardItemURL,
                    isDirectory: isDirectory,
                    isExecutable: isExecutable,
                    isSymlink: isSymlink,
                    size: size,
                    modificationDate: date,
                    category: category,
                    isParentDir: false
                )
                items.append(item)
            }
        } catch {
            print("Error loading directory \(standardURL.path): \(error)")
        }
        
        return items
    }
    
    private func determineCategory(url: URL, isDirectory: Bool, isExecutable: Bool, isSymlink: Bool) -> FileCategory {
        if isDirectory {
            return .directory
        }
        if isSymlink {
            return .symlink
        }
        if isExecutable {
            return .executable
        }
        
        let ext = url.pathExtension.lowercased()
        let archiveExts: Set<String> = ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "dmg", "pkg"]
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic", "svg", "icns"]
        let documentExts: Set<String> = ["txt", "md", "swift", "c", "cpp", "h", "py", "sh", "json", "xml", "html", "css", "js", "ts", "yaml", "yml", "pdf", "rtf", "log"]
        
        if archiveExts.contains(ext) {
            return .archive
        } else if imageExts.contains(ext) {
            return .image
        } else if documentExts.contains(ext) {
            return .document
        } else {
            return .regular
        }
    }
    
    /// Méret formázása Midnight Commander stílusban
    func formatSize(bytes: Int64, isDirectory: Bool, isParent: Bool) -> String {
        if isParent {
            return "UP--DIR"
        }
        if isDirectory {
            return "DIR"
        }
        if bytes < 1024 {
            return "\(bytes)"
        } else if bytes < 1024 * 1024 {
            let kb = Double(bytes) / 1024.0
            return String(format: "%.1fK", kb)
        } else if bytes < 1024 * 1024 * 1024 {
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return String(format: "%.1fM", mb)
        } else {
            let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.1fG", gb)
        }
    }
    
    /// Dátum formázása Midnight Commander stílusban (pl. Nov 07 16:50)
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM dd HH:mm"
        return formatter.string(from: date)
    }
    
    /// Másolás
    func copy(items: [URL], to target: URL) throws {
        for source in items {
            let destination = try destinationURL(for: source, target: target, itemCount: items.count)
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    /// Másolás előre feloldott célútvonalakkal.
    func copy(items: [URL], to destinations: [URL], overwriting: Set<URL>) throws {
        guard items.count == destinations.count else { return }

        for (source, destination) in zip(items, destinations) {
            if fileManager.fileExists(atPath: destination.path) {
                guard overwriting.contains(destination) else { continue }
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }
    
    /// Áthelyezés
    func move(items: [URL], to target: URL) throws {
        for source in items {
            let destination = try destinationURL(for: source, target: target, itemCount: items.count)
            try fileManager.moveItem(at: source, to: destination)
        }
    }

    /// Áthelyezés előre feloldott célútvonalakkal.
    func move(items: [URL], to destinations: [URL], overwriting: Set<URL>) throws {
        guard items.count == destinations.count else { return }

        for (source, destination) in zip(items, destinations) {
            if fileManager.fileExists(atPath: destination.path) {
                guard overwriting.contains(destination) else { continue }
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: source, to: destination)
        }
    }
    
    /// Megadott célkönyvtár vagy egyetlen fájl teljes célútvonalának feloldása.
    private func destinationURL(for source: URL, target: URL, itemCount: Int) throws -> URL {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: target.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return target.appendingPathComponent(source.lastPathComponent)
        }
        
        guard itemCount == 1 else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "Több fájl másolásakor vagy mozgatásakor célkönyvtárat kell megadni."
            ])
        }
        
        let parentDirectory = target.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: parentDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "A célkönyvtár nem létezik."
            ])
        }
        
        return target
    }
    
    /// Átnevezés
    func rename(item: URL, newName: String) throws {
        let destination = item.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: item, to: destination)
    }
    
    /// Törlés rekurzívan: könyvtáraknál előbb a tartalom, majd maga a könyvtár törlődik.
    func delete(items: [URL]) throws {
        for item in items {
            do {
                try deleteRecursively(at: item)

                // A törlés után ellenőrizzük a kijelölt gyökérelemet is.
                // Ha valamiért megmaradt, egyben a Kukába helyezzük.
                if fileManager.fileExists(atPath: item.path) {
                    try fileManager.trashItem(at: item, resultingItemURL: nil)
                }
            } catch {
                // Ha egy elem zárolt vagy a közvetlen törlés nem teljesül,
                // a teljes kijelölt elemet egyben a Kukába helyezzük.
                try fileManager.trashItem(at: item, resultingItemURL: nil)
            }
        }
    }

    private func deleteRecursively(at url: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        guard exists else { return }

        if isDirectory.boolValue {
            let children = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )

            for child in children {
                try deleteRecursively(at: child)
            }
        }

        try fileManager.removeItem(at: url)
    }
    
    /// Új könyvtár létrehozása
    func createDirectory(named name: String, at folder: URL) throws {
        let newDirURL = folder.appendingPathComponent(name)
        try fileManager.createDirectory(at: newDirURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    /// Fájl szöveges olvasása
    func readFileContent(at url: URL) -> String? {
        if let data = try? Data(contentsOf: url),
           let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            return string
        }
        return nil
    }
    
    /// Fájl mentése
    func saveFileContent(content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Fájl megnyitása az alapértelmezett macOS alkalmazással
    func openFile(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.path]
        try process.run()
    }
    
    /// Fájlok és könyvtárak tömörítése gzip-pelt tar archívumba.
    func createTGZ(items: [URL], named name: String, in directory: URL, relativeTo sourceDirectory: URL) throws {
        let archiveName = name.lowercased().hasSuffix(".tgz") ? name : "\(name).tgz"
        let archiveURL = directory.appendingPathComponent(archiveName).standardizedFileURL
        let sourceNames = items.map { $0.lastPathComponent }
        guard !sourceNames.isEmpty else { return }

        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", archiveURL.path, "--"] + sourceNames
        process.currentDirectoryURL = sourceDirectory
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "FileService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorOutput.isEmpty ? "tar failed" : errorOutput])
        }
    }

    /// Két fájl vagy könyvtár összehasonlítása Meld-del
    func compareWithMeld(file1: URL, file2: URL) throws {
        let process = Process()
        
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/meld") {
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/meld")
            process.arguments = [file1.path, file2.path]
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/meld") {
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/meld")
            process.arguments = [file1.path, file2.path]
        } else if FileManager.default.fileExists(atPath: "/Applications/Meld.app") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Meld", "--args", file1.path, file2.path]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Meld", file1.path, file2.path]
        }
        
        try process.run()
    }
    
    /// Két könyvtár különböző elemeinek meghatározása panelenként
    func findDirectoryDifferences(left: URL, right: URL) -> (left: Set<URL>, right: Set<URL>) {
        let leftItems = loadDirectory(at: left, showHidden: true)
            .filter { !$0.isParentDir }
        let rightItems = loadDirectory(at: right, showHidden: true)
            .filter { !$0.isParentDir }
        
        let leftByName = Dictionary(uniqueKeysWithValues: leftItems.map { ($0.name, $0) })
        let rightByName = Dictionary(uniqueKeysWithValues: rightItems.map { ($0.name, $0) })
        let allNames = Set(leftByName.keys).union(rightByName.keys)
        
        var leftDifferences: Set<URL> = []
        var rightDifferences: Set<URL> = []
        
        for name in allNames {
            guard let leftItem = leftByName[name] else {
                if let rightItem = rightByName[name] {
                    rightDifferences.insert(rightItem.url)
                }
                continue
            }
            
            guard let rightItem = rightByName[name] else {
                leftDifferences.insert(leftItem.url)
                continue
            }
            
            let typeDiffers = leftItem.isDirectory != rightItem.isDirectory
            let metadataDiffers = !leftItem.isDirectory &&
                (leftItem.size != rightItem.size ||
                 abs(leftItem.modificationDate.timeIntervalSince(rightItem.modificationDate)) > 1)
            
            if typeDiffers || metadataDiffers {
                leftDifferences.insert(leftItem.url)
                rightDifferences.insert(rightItem.url)
            }
        }
        
        return (leftDifferences, rightDifferences)
    }
    
    /// Két könyvtár közvetlen tartalmának összehasonlítása Total Commander-szerű riporttal
    func compareDirectories(left: URL, right: URL) -> String {
        let leftItems = loadDirectory(at: left, showHidden: true)
            .filter { !$0.isParentDir }
        let rightItems = loadDirectory(at: right, showHidden: true)
            .filter { !$0.isParentDir }
        
        let leftByName = Dictionary(uniqueKeysWithValues: leftItems.map { ($0.name, $0) })
        let rightByName = Dictionary(uniqueKeysWithValues: rightItems.map { ($0.name, $0) })
        let allNames = Set(leftByName.keys).union(rightByName.keys)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        
        var onlyLeft: [String] = []
        var onlyRight: [String] = []
        var different: [String] = []
        var identicalCount = 0
        
        for name in allNames {
            guard let leftItem = leftByName[name] else {
                onlyRight.append(name)
                continue
            }
            guard let rightItem = rightByName[name] else {
                onlyLeft.append(name)
                continue
            }
            
            if leftItem.isDirectory != rightItem.isDirectory {
                different.append("\(name) (type differs)")
            } else if !leftItem.isDirectory &&
                        (leftItem.size != rightItem.size ||
                         abs(leftItem.modificationDate.timeIntervalSince(rightItem.modificationDate)) > 1) {
                different.append("\(name) (content metadata differs)")
            } else {
                identicalCount += 1
            }
        }
        
        var lines = [
            "Directory comparison",
            "Left:  \(left.path)",
            "Right: \(right.path)",
            ""
        ]
        
        if onlyLeft.isEmpty && onlyRight.isEmpty && different.isEmpty {
            lines.append("Directories are identical.")
        } else {
            lines.append("Only in left:")
            lines.append(contentsOf: onlyLeft.isEmpty ? ["  (none)"] : onlyLeft.map { "  \($0)" })
            lines.append("")
            lines.append("Only in right:")
            lines.append(contentsOf: onlyRight.isEmpty ? ["  (none)"] : onlyRight.map { "  \($0)" })
            lines.append("")
            lines.append("Different:")
            lines.append(contentsOf: different.isEmpty ? ["  (none)"] : different.map { "  \($0)" })
            lines.append("")
            lines.append("Identical entries: \(identicalCount)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Shell parancs futtatása
    func executeShellCommand(_ command: String, workingDirectory: URL) -> (output: String, error: String?, exitCode: Int32) {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.currentDirectoryURL = workingDirectory
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8)
            
            return (output, (error?.isEmpty ?? true) ? nil : error, process.terminationStatus)
        } catch {
            return ("", error.localizedDescription, -1)
        }
    }
}
