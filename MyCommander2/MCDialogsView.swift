import SwiftUI

struct MCDialogsView: View {
    @Bindable var appState: MCAppState
    
    var body: some View {
        Group {
            switch appState.activeDialog {
            case .view(let url):
                FileViewerDialog(url: url) {
                    appState.activeDialog = nil
                }
            case .edit(let url):
                FileEditorDialog(url: url) {
                    appState.leftPanel.refresh()
                    appState.rightPanel.refresh()
                    appState.activeDialog = nil
                }
            case .copy(let sources, let dest):
                CopyMoveDialog(
                    isMove: false,
                    sources: sources,
                    initialDestination: dest
                ) { targetURL in
                    do {
                        try FileService.shared.copy(items: sources, to: targetURL)
                        appState.statusMessage = "Copied \(sources.count) item(s) to \(targetURL.lastPathComponent)"
                        appState.leftPanel.refresh()
                        appState.rightPanel.refresh()
                        appState.currentActivePanel.clearMarks()
                    } catch {
                        appState.statusMessage = "Copy error: \(error.localizedDescription)"
                    }
                    appState.activeDialog = nil
                } onCancel: {
                    appState.activeDialog = nil
                }
            case .archive(let sources, let directory, let sourceDirectory):
                ArchiveDialog(sources: sources, directory: directory) { archiveName in
                    do {
                        try FileService.shared.createTGZ(items: sources, named: archiveName, in: directory, relativeTo: sourceDirectory)
                        let finalName = archiveName.lowercased().hasSuffix(".tgz") ? archiveName : archiveName + ".tgz"
                        appState.statusMessage = "Created \(finalName)"
                        appState.leftPanel.refresh()
                        appState.rightPanel.refresh()
                        appState.currentActivePanel.clearMarks()
                    } catch {
                        appState.statusMessage = "TGZ error: \(error.localizedDescription)"
                    }
                    appState.activeDialog = nil
                } onCancel: {
                    appState.activeDialog = nil
                }
            case .move(let sources, let dest):
                CopyMoveDialog(
                    isMove: true,
                    sources: sources,
                    initialDestination: dest
                ) { targetURL in
                    do {
                        try FileService.shared.move(items: sources, to: targetURL)
                        appState.statusMessage = "Moved \(sources.count) item(s) to \(targetURL.lastPathComponent)"
                        appState.leftPanel.refresh()
                        appState.rightPanel.refresh()
                        appState.currentActivePanel.clearMarks()
                    } catch {
                        appState.statusMessage = "Move error: \(error.localizedDescription)"
                    }
                    appState.activeDialog = nil
                } onCancel: {
                    appState.activeDialog = nil
                }
            case .mkdir(let currentURL):
                MkdirDialog(currentURL: currentURL) { dirName in
                    do {
                        try FileService.shared.createDirectory(named: dirName, at: currentURL)
                        appState.statusMessage = "Directory created: \(dirName)"
                        appState.leftPanel.refresh()
                        appState.rightPanel.refresh()
                    } catch {
                        appState.statusMessage = "Create directory error: \(error.localizedDescription)"
                    }
                    appState.activeDialog = nil
                } onCancel: {
                    appState.activeDialog = nil
                }
            case .delete(let targets):
                DeleteConfirmDialog(targets: targets) {
                    do {
                        try FileService.shared.delete(items: targets)
                        appState.statusMessage = "Deleted \(targets.count) item(s)"
                        appState.leftPanel.refresh()
                        appState.rightPanel.refresh()
                        appState.currentActivePanel.clearMarks()
                    } catch {
                        appState.statusMessage = "Delete error: \(error.localizedDescription)"
                    }
                    appState.activeDialog = nil
                } onCancel: {
                    appState.activeDialog = nil
                }
            case .help:
                HelpDialog {
                    appState.activeDialog = nil
                }
            case .commandOutput(let title, let output, let isError):
                CommandOutputDialog(title: title, output: output, isError: isError) {
                    appState.activeDialog = nil
                }
            case .none:
                EmptyView()
            }
        }
    }
}

// MARK: - F3 File Viewer
struct FileViewerDialog: View {
    let url: URL
    let onClose: () -> Void
    
    @State private var content: String = "Loading..."
    @State private var isImage: Bool = false
    @State private var nsImage: NSImage? = nil
    @FocusState private var isViewerFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Fejléc
                HStack {
                    Text(" View: \(url.lastPathComponent) ")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.black)
                    Spacer()
                    Button("[ Esc / Close ]") {
                        onClose()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.black)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.0, green: 0.8, blue: 0.8))
                
                // Tartalom
                if isImage, let img = nsImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        Text(content)
                            .font(MCTheme.monoFont)
                            .foregroundColor(MCTheme.regularFile)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(Color(red: 0.0, green: 0.0, blue: 0.4))
                }
                
                // Információs lábléc
                HStack {
                    Text(url.path)
                        .font(MCTheme.monoSmall)
                        .foregroundColor(Color.cyan)
                        .lineLimit(1)
                    Spacer()
                    Text("Press ESC to close")
                        .font(MCTheme.monoSmall)
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(red: 0.0, green: 0.15, blue: 0.4))
            }
            .frame(width: 800, height: 550)
            .border(MCTheme.activeBorder, width: 2)
            .shadow(radius: 12)
        }
        .focusable()
        .focused($isViewerFocused)
        .focusEffectDisabled()
        .onAppear {
            loadFile()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isViewerFocused = true
            }
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
    
    private func loadFile() {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic"]
        if imageExts.contains(url.pathExtension.lowercased()) {
            isImage = true
            nsImage = NSImage(contentsOf: url)
        } else {
            isImage = false
            content = FileService.shared.readFileContent(at: url) ?? "[Binary file or cannot read as UTF-8 / Text]"
        }
    }
}

// MARK: - F4 File Editor (mcedit)
struct FileEditorDialog: View {
    let url: URL
    let onFinished: () -> Void
    
    @State private var text: String = ""
    @State private var isModified: Bool = false
    @State private var saveStatus: String = ""
    @FocusState private var isEditorFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Fejléc
                HStack {
                    Text(" Edit: \(url.lastPathComponent) \(isModified ? "[*Modified]" : "")")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.black)
                    Spacer()
                    Text(saveStatus)
                        .font(MCTheme.monoSmall)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.0, green: 0.8, blue: 0.8))
                
                // Szerkesztő felület
                TextEditor(text: $text)
                    .font(MCTheme.monoFont)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.0, green: 0.0, blue: 0.5))
                    .padding(4)
                    .focused($isEditorFocused)
                    .onChange(of: text) { _, _ in
                        isModified = true
                    }
                
                // Lábléc gombokkal
                HStack(spacing: 12) {
                    Button("[ ⌘S / Save ]") {
                        save()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .font(MCTheme.monoBold)
                    .foregroundColor(.black)
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button("[ Esc / Close ]") {
                        onFinished()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.black)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.0, green: 0.8, blue: 0.8))
            }
            .frame(width: 800, height: 550)
            .border(MCTheme.activeBorder, width: 2)
            .shadow(radius: 12)
        }
        .onAppear {
            text = FileService.shared.readFileContent(at: url) ?? ""
            isModified = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isEditorFocused = true
            }
        }
        .onKeyPress(.escape) {
            onFinished()
            return .handled
        }
    }
    
    private func save() {
        do {
            try FileService.shared.saveFileContent(content: text, to: url)
            isModified = false
            saveStatus = "Saved!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                saveStatus = ""
            }
        } catch {
            saveStatus = "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - F5 / F6 Copy & Move Dialog
struct CopyMoveDialog: View {
    let isMove: Bool
    let sources: [URL]
    let initialDestination: URL
    let onConfirm: (URL) -> Void
    let onCancel: () -> Void
    
    @State private var targetPath: String = ""
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 12) {
                // Címsor
                HStack {
                    Text(isMove ? " Ren/Move " : " Copy ")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(red: 0.0, green: 0.8, blue: 0.8))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(isMove ? "Move" : "Copy") \(sources.count) file(s):")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.yellow)
                    
                    Text(sources.map { $0.lastPathComponent }.joined(separator: ", "))
                        .font(MCTheme.monoSmall)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(sources.count == 1
                         ? "to target directory or new file path:"
                         : "to target directory:")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.white)
                        .padding(.top, 4)
                    
                    // Egyetlen fájlnál a célfájlt teljes útvonallal is meg lehet adni.
                    TextField("", text: $targetPath)
                        .textFieldStyle(.plain)
                        .font(MCTheme.monoFont)
                        .foregroundColor(.black)
                        .padding(4)
                        .background(Color.white)
                        .border(Color.black, width: 1)
                        .focused($isFieldFocused)
                        .onSubmit {
                            submit()
                        }
                }
                .padding(.horizontal, 12)
                
                HStack(spacing: 16) {
                    Spacer()
                    Button("[ OK ]") {
                        submit()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.0, green: 0.5, blue: 0.5))
                    .buttonStyle(.plain)
                    
                    Button("[ Cancel ]") {
                        onCancel()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.4, green: 0.4, blue: 0.4))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .frame(width: 520)
            .background(MCTheme.panelBackground)
            .border(MCTheme.activeBorder, width: 2)
            .shadow(radius: 12)
        }
        .onAppear {
            targetPath = initialDestination.path
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFieldFocused = true
            }
        }
        .onKeyPress(.return) {
            submit()
            return .handled
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
    
    private func submit() {
        let trimmed = targetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let url: URL
            if sources.count == 1 && !trimmed.contains("/") {
                // Mozgatásnál a puszta fájlnév ugyanabban a könyvtárban átnevezést jelent.
                let directory = isMove
                    ? sources[0].deletingLastPathComponent()
                    : initialDestination
                url = directory.appendingPathComponent(trimmed).standardizedFileURL
            } else {
                url = URL(fileURLWithPath: trimmed).standardizedFileURL
            }
            onConfirm(url)
        }
    }
}

// MARK: - TGZ Archive Dialog
struct ArchiveDialog: View {
    let sources: [URL]
    let directory: URL
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var archiveName: String = "archive.tgz"
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(" Create TGZ Archive ")
                    .font(MCTheme.monoBold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.0, green: 0.8, blue: 0.8))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Compress \(sources.count) item(s):")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.yellow)
                    Text(sources.map { $0.lastPathComponent }.joined(separator: ", "))
                        .font(MCTheme.monoSmall)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text("Archive name in \(directory.lastPathComponent):")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.white)
                    TextField("archive.tgz", text: $archiveName)
                        .textFieldStyle(.plain)
                        .font(MCTheme.monoFont)
                        .foregroundColor(.black)
                        .padding(4)
                        .background(Color.white)
                        .border(Color.black, width: 1)
                        .focused($isFieldFocused)
                        .onSubmit { submit() }
                }
                .padding(.horizontal, 12)

                HStack(spacing: 16) {
                    Spacer()
                    Button("[ OK ]") { submit() }
                        .font(MCTheme.monoBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.0, green: 0.5, blue: 0.5))
                        .buttonStyle(.plain)
                    Button("[ Cancel ]") { onCancel() }
                        .font(MCTheme.monoBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .frame(width: 560)
            .background(MCTheme.panelBackground)
            .border(MCTheme.activeBorder, width: 2)
            .shadow(radius: 12)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isFieldFocused = true }
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }

    private func submit() {
        let trimmed = archiveName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { onConfirm(trimmed) }
    }
}

// MARK: - F7 Mkdir Dialog
struct MkdirDialog: View {
    let currentURL: URL
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var directoryName: String = ""
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(" Create New Directory ")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(red: 0.0, green: 0.8, blue: 0.8))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Directory in: \(currentURL.lastPathComponent)")
                        .font(MCTheme.monoSmall)
                        .foregroundColor(.white)
                    
                    Text("Enter directory name:")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.yellow)
                    
                    TextField("", text: $directoryName)
                        .textFieldStyle(.plain)
                        .font(MCTheme.monoFont)
                        .foregroundColor(.black)
                        .padding(4)
                        .background(Color.white)
                        .border(Color.black, width: 1)
                        .focused($isFieldFocused)
                        .onSubmit {
                            submit()
                        }
                }
                .padding(.horizontal, 12)
                
                HStack(spacing: 16) {
                    Spacer()
                    Button("[ OK ]") {
                        submit()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.0, green: 0.5, blue: 0.5))
                    .buttonStyle(.plain)
                    
                    Button("[ Cancel ]") {
                        onCancel()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.4, green: 0.4, blue: 0.4))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .frame(width: 450)
            .background(MCTheme.panelBackground)
            .border(MCTheme.activeBorder, width: 2)
            .shadow(radius: 12)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFieldFocused = true
            }
        }
        .onKeyPress(.return) {
            submit()
            return .handled
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
    
    private func submit() {
        let trimmed = directoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onConfirm(trimmed)
        }
    }
}

// MARK: - F8 Delete Confirm Dialog
struct DeleteConfirmDialog: View {
    let targets: [URL]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @FocusState private var isDialogFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(" Delete Confirmation ")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.red)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Do you really want to delete \(targets.count) item(s)?")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.yellow)
                    
                    Text(targets.map { $0.lastPathComponent }.joined(separator: ", "))
                        .font(MCTheme.monoSmall)
                        .foregroundColor(.white)
                        .lineLimit(3)
                    
                    Text("Warning: This cannot be undone!")
                        .font(MCTheme.monoSmall)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                
                HStack(spacing: 16) {
                    Spacer()
                    Button("[ Delete ]") {
                        onConfirm()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .buttonStyle(.plain)
                    
                    Button("[ Cancel ]") {
                        onCancel()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.4, green: 0.4, blue: 0.4))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .frame(width: 480)
            .background(MCTheme.panelBackground)
            .border(Color.red, width: 2)
            .shadow(radius: 12)
        }
        .focusable()
        .focused($isDialogFocused)
        .focusEffectDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isDialogFocused = true
            }
        }
        .onKeyPress(.return) {
            onConfirm()
            return .handled
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
}

// MARK: - F1 Help Dialog
struct HelpDialog: View {
    let onClose: () -> Void
    @FocusState private var isHelpFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(" Midnight Commander Help ")
                        .font(MCTheme.monoBold)
                        .foregroundColor(.black)
                    Spacer()
                    Button("[ Esc / Close ]") {
                        onClose()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(.black)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.0, green: 0.8, blue: 0.8))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("KEYBOARD SHORTCUTS & NAVIGATION:")
                            .font(MCTheme.monoBold)
                            .foregroundColor(.yellow)
                        
                        helpRow("Tab", "Switch active panel (Left <-> Right)")
                        helpRow("Up / Down", "Move cursor through items")
                        helpRow("Enter / Double Click", "Enter directory or view file")
                        helpRow("Space / [*]", "Select / Tag items for multi-action")
                        helpRow("F1 / ⌘1", "Show this help screen")
                        helpRow("F3 / ⌘3", "View selected file")
                        helpRow("F4 / ⌘4", "Edit selected file")
                        helpRow("F5 / ⌘5", "Copy file(s) to the other panel")
                        helpRow("F6 / ⌘6", "Rename or Move file(s) to the other panel")
                        helpRow("F7 / ⌘7", "Create new directory")
                        helpRow("F8 / ⌘8", "Delete selected file(s)")
                        helpRow("F9 / ⌘9", "Switch panel")
                        helpRow("F10 / ⌘0", "Quit Midnight Commander")
                        
                        Divider().background(Color.cyan)
                        
                        Text("BUILT-IN COMMAND LINE:")
                            .font(MCTheme.monoBold)
                            .foregroundColor(.yellow)
                        Text("• Type shell commands at the bottom prompt (e.g. `cd ..`, `ls -la`, `pwd`, `touch test.txt`) and press Enter.")
                            .font(MCTheme.monoFont)
                            .foregroundColor(.white)
                    }
                    .padding(14)
                }
                .background(MCTheme.panelBackground)
            }
            .frame(width: 580, height: 440)
            .border(MCTheme.activeBorder, width: 2)
            .shadow(radius: 12)
        }
        .focusable()
        .focused($isHelpFocused)
        .focusEffectDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isHelpFocused = true
            }
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
    
    private func helpRow(_ key: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(MCTheme.monoBold)
                .foregroundColor(Color.cyan)
                .frame(width: 130, alignment: .leading)
            Text(desc)
                .font(MCTheme.monoFont)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Command Output Dialog
struct CommandOutputDialog: View {
    let title: String
    let output: String
    let isError: Bool
    let onClose: () -> Void
    @FocusState private var isDialogFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Text(" Terminal: \(title) ")
                        .font(MCTheme.monoBold)
                        .foregroundColor(isError ? .white : .black)
                    Spacer()
                    Button("[ Esc / Close ]") {
                        onClose()
                    }
                    .font(MCTheme.monoBold)
                    .foregroundColor(isError ? .white : .black)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isError ? Color.red : Color(red: 0.0, green: 0.8, blue: 0.8))
                
                ScrollView {
                    Text(output)
                        .font(MCTheme.monoFont)
                        .foregroundColor(isError ? Color(red: 1.0, green: 0.6, blue: 0.6) : .green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
            .frame(width: 700, height: 420)
            .border(isError ? Color.red : MCTheme.activeBorder, width: 2)
            .shadow(radius: 12)
        }
        .focusable()
        .focused($isDialogFocused)
        .focusEffectDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isDialogFocused = true
            }
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
}
