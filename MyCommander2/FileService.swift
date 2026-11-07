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
    func copy(items: [URL], to targetFolder: URL) throws {
        for source in items {
            let destination = targetFolder.appendingPathComponent(source.lastPathComponent)
            try fileManager.copyItem(at: source, to: destination)
        }
    }
    
    /// Áthelyezés
    func move(items: [URL], to targetFolder: URL) throws {
        for source in items {
            let destination = targetFolder.appendingPathComponent(source.lastPathComponent)
            try fileManager.moveItem(at: source, to: destination)
        }
    }
    
    /// Átnevezés
    func rename(item: URL, newName: String) throws {
        let destination = item.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: item, to: destination)
    }
    
    /// Törlés (Kukába vagy közvetlen törlés)
    func delete(items: [URL]) throws {
        for item in items {
            try fileManager.removeItem(at: item)
        }
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
