import Foundation
import SwiftUI
import Observation

@Observable
class PanelState {
    private let savedDirectoryKey: String?
    var currentDirectory: URL
    var items: [FileItem] = []
    var selectedItemId: String? = nil
    var selectedIndex: Int = 0
    var markedURLs: Set<URL> = []
    var sortField: SortField = .name
    var sortOrder: SortOrder = .ascending
    var showHidden: Bool = false
    var filterText: String = ""
    var shouldFocusFilter: Bool = false
    var isFilterFocused: Bool = false
    
    init(directory: URL, savedDirectoryKey: String? = nil) {
        self.savedDirectoryKey = savedDirectoryKey
        self.currentDirectory = directory.standardizedFileURL
        refresh()
    }
    
    var filteredItems: [FileItem] {
        var result = items
        if !filterText.isEmpty {
            result = result.filter { item in
                if item.isParentDir { return true }
                return item.name.localizedCaseInsensitiveContains(filterText)
            }
        }
        
        let parentItems = result.filter { $0.isParentDir }
        var nonParentItems = result.filter { !$0.isParentDir }
        
        nonParentItems.sort { a, b in
            // Mindig a mappák legyenek elöl
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            
            let isAsc = sortOrder == .ascending
            switch sortField {
            case .name:
                let res = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                return isAsc ? res : !res
            case .size:
                let res = a.size < b.size
                return isAsc ? res : !res
            case .date:
                let res = a.modificationDate < b.modificationDate
                return isAsc ? res : !res
            }
        }
        
        return parentItems + nonParentItems
    }
    
    var selectedItem: FileItem? {
        let list = filteredItems
        guard !list.isEmpty else { return nil }
        
        if let id = selectedItemId, let match = list.first(where: { $0.id == id }) {
            return match
        }
        
        if selectedIndex >= 0 && selectedIndex < list.count {
            return list[selectedIndex]
        }
        return list.first
    }
    
    func select(item: FileItem) {
        selectedItemId = item.id
        if let idx = filteredItems.firstIndex(where: { $0.id == item.id }) {
            selectedIndex = idx
        }
    }
    
    func refresh() {
        let oldIndex = selectedIndex
        let loaded = FileService.shared.loadDirectory(at: currentDirectory, showHidden: showHidden)
        self.items = loaded
        
        let list = filteredItems
        if let id = selectedItemId, let item = list.first(where: { $0.id == id }) {
            select(item: item)
        } else if !list.isEmpty {
            // Ha a kijelölt elem törlődött, azonos indexű vagy előző elemre állunk rá
            let targetIndex = max(0, min(oldIndex, list.count - 1))
            select(item: list[targetIndex])
        } else {
            selectedItemId = nil
            selectedIndex = 0
        }
    }
    
    func navigateTo(directory: URL) {
        let previousDir = currentDirectory
        let targetDir = directory.standardizedFileURL
        
        currentDirectory = targetDir
        if let savedDirectoryKey {
            UserDefaults.standard.set(targetDir.path, forKey: savedDirectoryKey)
        }
        markedURLs.removeAll()
        filterText = ""
        refresh()
        
        // Ha a szülőkönyvtárba léptünk vissza, állítsuk a kurzort a korábbi mappára!
        if previousDir.deletingLastPathComponent().standardizedFileURL.path == targetDir.path {
            if let prevFolderItem = filteredItems.first(where: { $0.url.path == previousDir.path }) {
                select(item: prevFolderItem)
                return
            }
        }
        
        // Különben az első elérhető elemre állunk
        if let first = filteredItems.first {
            select(item: first)
        } else {
            selectedItemId = nil
            selectedIndex = 0
        }
    }
    
    func toggleMark(for url: URL) {
        if markedURLs.contains(url) {
            markedURLs.remove(url)
        } else {
            markedURLs.insert(url)
        }
    }
    
    func clearMarks() {
        markedURLs.removeAll()
    }
    
    func selectAll() {
        for item in items where !item.isParentDir {
            markedURLs.insert(item.url)
        }
    }
    
    func moveSelection(by delta: Int) {
        let list = filteredItems
        guard !list.isEmpty else { return }
        
        var currentIdx = selectedIndex
        if let id = selectedItemId, let idx = list.firstIndex(where: { $0.id == id }) {
            currentIdx = idx
        }
        
        let newIdx = max(0, min(list.count - 1, currentIdx + delta))
        selectedIndex = newIdx
        selectedItemId = list[newIdx].id
    }
    
    var summaryText: String {
        let nonParents = items.filter { !$0.isParentDir }
        let dirCount = nonParents.filter { $0.isDirectory }.count
        let fileCount = nonParents.count - dirCount
        let totalBytes = nonParents.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
        let formattedSize = FileService.shared.formatSize(bytes: totalBytes, isDirectory: false, isParent: false)
        
        if markedURLs.isEmpty {
            return "\(fileCount) files, \(dirCount) dirs (\(formattedSize))"
        } else {
            let markedBytes = nonParents.filter { markedURLs.contains($0.url) && !$0.isDirectory }.reduce(0) { $0 + $1.size }
            let markedSize = FileService.shared.formatSize(bytes: markedBytes, isDirectory: false, isParent: false)
            return "\(markedURLs.count) tagged (\(markedSize)) / \(fileCount) files"
        }
    }
}

enum ActiveDialog: Identifiable {
    case view(URL)
    case edit(URL)
    case copy(sources: [URL], destination: URL)
    case move(sources: [URL], destination: URL)
    case archive(sources: [URL], directory: URL, sourceDirectory: URL)
    case mkdir(currentURL: URL)
    case delete(targets: [URL])
    case help
    case commandOutput(title: String, output: String, isError: Bool)
    
    var id: String {
        switch self {
        case .view(let url): return "view_\(url.path)"
        case .edit(let url): return "edit_\(url.path)"
        case .copy: return "copy"
        case .move: return "move"
        case .archive: return "archive"
        case .mkdir: return "mkdir"
        case .delete: return "delete"
        case .help: return "help"
        case .commandOutput(let title, _, _): return "cmd_\(title)"
        }
    }
}

@Observable
class MCAppState {
    var leftPanel: PanelState
    var rightPanel: PanelState
    var activePanel: PanelSide = .left
    var activeDialog: ActiveDialog? = nil
    var commandInput: String = ""
    var shouldFocusCommandPrompt: Bool = false
    var isCommandPromptFocused: Bool = false
    var statusMessage: String = "Midnight Commander for macOS - Ready"
    
    init() {
        let home = FileService.shared.defaultDirectory
        let leftDirectory = Self.savedDirectory(forKey: "leftPanelDirectory", fallback: home)
        let rightDirectory = Self.savedDirectory(forKey: "rightPanelDirectory", fallback: home)
        self.leftPanel = PanelState(directory: leftDirectory, savedDirectoryKey: "leftPanelDirectory")
        self.rightPanel = PanelState(directory: rightDirectory, savedDirectoryKey: "rightPanelDirectory")
    }
    
    private static func savedDirectory(forKey key: String, fallback: URL) -> URL {
        guard
            let path = UserDefaults.standard.string(forKey: key),
            !path.isEmpty
        else {
            return fallback
        }
        
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue ? URL(fileURLWithPath: path) : fallback
    }
    
    var currentActivePanel: PanelState {
        return activePanel == .left ? leftPanel : rightPanel
    }
    
    var inactivePanel: PanelState {
        return activePanel == .left ? rightPanel : leftPanel
    }
    
    func switchPanel() {
        activePanel = (activePanel == .left) ? .right : .left
    }
    
    func syncInactivePanelDirectory() {
        inactivePanel.navigateTo(directory: currentActivePanel.currentDirectory)
    }
    
    // Műveletek elindítása az aktív panel alapján
    func triggerAction(_ fnNumber: Int) {
        switch fnNumber {
        case 1: // Help
            activeDialog = .help
        case 2: // TGZ
            let sources = selectedURLsOrCurrent()
            if !sources.isEmpty {
                activeDialog = .archive(sources: sources, directory: inactivePanel.currentDirectory, sourceDirectory: currentActivePanel.currentDirectory)
            } else {
                statusMessage = "Nothing selected to archive."
            }
        case 3: // View
            if let item = currentActivePanel.selectedItem, !item.isDirectory {
                activeDialog = .view(item.url)
            } else {
                statusMessage = "Select a file to view."
            }
        case 4: // Edit
            if let item = currentActivePanel.selectedItem, !item.isDirectory {
                activeDialog = .edit(item.url)
            } else {
                statusMessage = "Select a file to edit."
            }
        case 5: // Copy
            let sources = selectedURLsOrCurrent()
            if !sources.isEmpty {
                activeDialog = .copy(sources: sources, destination: inactivePanel.currentDirectory)
            } else {
                statusMessage = "Nothing selected to copy."
            }
        case 6: // RenMov
            let sources = selectedURLsOrCurrent()
            if !sources.isEmpty {
                activeDialog = .move(sources: sources, destination: inactivePanel.currentDirectory)
            } else {
                statusMessage = "Nothing selected to move/rename."
            }
        case 7: // Mkdir
            activeDialog = .mkdir(currentURL: currentActivePanel.currentDirectory)
        case 8: // Delete
            let sources = selectedURLsOrCurrent()
            if !sources.isEmpty {
                activeDialog = .delete(targets: sources)
            } else {
                statusMessage = "Nothing selected to delete."
            }
        case 9: // PullDn
            switchPanel()
        case 10: // Quit
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }
    
    func selectedURLsOrCurrent() -> [URL] {
        let panel = currentActivePanel
        if !panel.markedURLs.isEmpty {
            return Array(panel.markedURLs)
        }
        if let item = panel.selectedItem, !item.isParentDir {
            return [item.url]
        }
        return []
    }
    
    func openSelected() {
        guard let item = currentActivePanel.selectedItem else { return }
        if item.isParentDir {
            currentActivePanel.navigateTo(directory: item.url)
        } else if item.isDirectory {
            currentActivePanel.navigateTo(directory: item.url)
        } else {
            do {
                try FileService.shared.openFile(at: item.url)
                statusMessage = "Opening \(item.name)"
            } catch {
                statusMessage = "Open error: \(error.localizedDescription)"
            }
        }
    }
    
    /// Összehasonlítás Meld segítségével a két panel kijelölt elemei között (⌘Y)
    func compareWithMeld() {
        guard let leftItem = leftPanel.selectedItem else {
            statusMessage = "Meld: No item selected in left panel."
            return
        }
        guard let rightItem = rightPanel.selectedItem else {
            statusMessage = "Meld: No item selected in right panel."
            return
        }
        
        if leftItem.isParentDir || rightItem.isParentDir {
            statusMessage = "Meld: Cannot compare parent directory (/..)."
            return
        }
        
        do {
            try FileService.shared.compareWithMeld(file1: leftItem.url, file2: rightItem.url)
            statusMessage = "Meld: Comparing '\(leftItem.name)' and '\(rightItem.name)'"
        } catch {
            statusMessage = "Meld error: \(error.localizedDescription)"
        }
    }
    
    func compareDirectories() {
        let differences = FileService.shared.findDirectoryDifferences(
            left: leftPanel.currentDirectory,
            right: rightPanel.currentDirectory
        )
        
        leftPanel.clearMarks()
        rightPanel.clearMarks()
        
        for url in differences.left {
            leftPanel.markedURLs.insert(url)
        }
        for url in differences.right {
            rightPanel.markedURLs.insert(url)
        }
        
        let differenceCount = differences.left.count + differences.right.count
        statusMessage = differenceCount == 0
            ? "Directories are identical."
            : "\(differenceCount) differing item(s) marked."
    }
    
    func runCommand() {
        let trimmed = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        commandInput = ""
        
        // Speciális beépített parancs: cd
        if trimmed.hasPrefix("cd ") {
            let path = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            let newURL: URL
            if path == "~" {
                newURL = FileService.shared.defaultDirectory
            } else if path.hasPrefix("/") {
                newURL = URL(fileURLWithPath: path).standardizedFileURL
            } else {
                newURL = currentActivePanel.currentDirectory.appendingPathComponent(path).standardizedFileURL
            }
            
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: newURL.path, isDirectory: &isDir), isDir.boolValue {
                currentActivePanel.navigateTo(directory: newURL)
                statusMessage = "Changed directory to \(newURL.path)"
            } else {
                statusMessage = "Directory not found: \(path)"
            }
            return
        }
        
        // Shell parancs futtatása
        let res = FileService.shared.executeShellCommand(trimmed, workingDirectory: currentActivePanel.currentDirectory)
        leftPanel.refresh()
        rightPanel.refresh()
        
        let outputText = (res.output.isEmpty && (res.error == nil || res.error!.isEmpty)) ? "(Command executed successfully with no output)" : (res.output + (res.error.map { "\nError:\n" + $0 } ?? ""))
        activeDialog = .commandOutput(title: trimmed, output: outputText, isError: res.exitCode != 0)
    }
}
