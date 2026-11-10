import SwiftUI

struct FilePanelView: View {
    let side: PanelSide
    @Bindable var panelState: PanelState
    let isActive: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var scrollRequestID = 0
    @FocusState private var isFilterFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Felső panel fejléc (MC stílusú kék-cián keretben)
            headerView
            
            // Oszlopfejlécek
            columnHeadersView
            
            Divider()
                .background(MCTheme.panelBorder)
            
            // Fájllista
            fileListView
            
            Divider()
                .background(MCTheme.panelBorder)
            
            // Alsó sáv: Információk és gyorsműveletek
            footerView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MCTheme.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(isActive ? MCTheme.activeBorder : MCTheme.panelBorder, lineWidth: isActive ? 2 : 1)
        )
        .onChange(of: isFilterFocused) { _, focused in
            panelState.isFilterFocused = focused
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 6) {
            Text("[\(side.rawValue)]")
                .font(MCTheme.monoBold)
                .foregroundColor(isActive ? .yellow : .white)
            
            // Könyvtár útvonal
            Text(panelState.currentDirectory.path)
                .font(MCTheme.monoBold)
                .foregroundColor(isActive ? .white : Color(white: 0.8))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Gyors könyvtár ugró menü
            Menu {
                Button("Home (~)") {
                    panelState.navigateTo(directory: FileService.shared.defaultDirectory)
                }
                Button("Desktop") {
                    let url = FileService.shared.defaultDirectory.appendingPathComponent("Desktop")
                    panelState.navigateTo(directory: url)
                }
                Button("Documents") {
                    let url = FileService.shared.defaultDirectory.appendingPathComponent("Documents")
                    panelState.navigateTo(directory: url)
                }
                Button("Downloads") {
                    let url = FileService.shared.defaultDirectory.appendingPathComponent("Downloads")
                    panelState.navigateTo(directory: url)
                }
                Button("Root (/)") {
                    panelState.navigateTo(directory: URL(fileURLWithPath: "/"))
                }
                Divider()
                Button("Reload (Ctrl+R)") {
                    panelState.refresh()
                }
            } label: {
                Text("▾ Jump")
                    .font(MCTheme.monoSmall)
                    .foregroundColor(.yellow)
            }
            .menuStyle(.borderlessButton)
            
            // Rejtett fájlok kapcsoló
            Button {
                panelState.showHidden.toggle()
                panelState.refresh()
            } label: {
                Text(panelState.showHidden ? "[.*]" : "[·]")
                    .font(MCTheme.monoSmall)
                    .foregroundColor(panelState.showHidden ? .yellow : .white)
            }
            .buttonStyle(.plain)
            .help("Toggle hidden files")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? Color(red: 0.0, green: 0.35, blue: 0.65) : Color(red: 0.0, green: 0.2, blue: 0.45))
    }
    
    // MARK: - Oszlopfejlécek
    private var columnHeadersView: some View {
        HStack(spacing: 8) {
            Button {
                toggleSort(by: .name)
            } label: {
                HStack(spacing: 2) {
                    Text("Name")
                    if panelState.sortField == .name {
                        Text(panelState.sortOrder == .ascending ? "▲" : "▼")
                    }
                }
                .font(MCTheme.monoBold)
                .foregroundColor(panelState.sortField == .name ? .yellow : MCTheme.directory)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                toggleSort(by: .size)
            } label: {
                HStack(spacing: 2) {
                    Text("Size")
                    if panelState.sortField == .size {
                        Text(panelState.sortOrder == .ascending ? "▲" : "▼")
                    }
                }
                .font(MCTheme.monoBold)
                .foregroundColor(panelState.sortField == .size ? .yellow : MCTheme.directory)
                .frame(width: 75, alignment: .trailing)
            }
            .buttonStyle(.plain)
            
            Button {
                toggleSort(by: .date)
            } label: {
                HStack(spacing: 2) {
                    Text("Modify time")
                    if panelState.sortField == .date {
                        Text(panelState.sortOrder == .ascending ? "▲" : "▼")
                    }
                }
                .font(MCTheme.monoBold)
                .foregroundColor(panelState.sortField == .date ? .yellow : MCTheme.directory)
                .frame(width: 120, alignment: .trailing)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(red: 0.0, green: 0.15, blue: 0.4))
    }
    
    // MARK: - Fájllista
    private var fileListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(panelState.filteredItems) { item in
                        let isCursor = (panelState.selectedItem?.id == item.id)
                        let isMarked = panelState.markedURLs.contains(item.url)
                        
                        FileRowView(
                            item: item,
                            isCursor: isCursor,
                            isMarked: isMarked,
                            isActivePanel: isActive,
                            onSingleClick: {
                                onSelect()
                                panelState.select(item: item)
                            },
                            onDoubleClick: {
                                onSelect()
                                panelState.select(item: item)
                                onOpen()
                            },
                            onToggleMark: {
                                panelState.toggleMark(for: item.url)
                            }
                        )
                        .onGeometryChange(for: CGRect.self) { geometry in
                            geometry.frame(in: .scrollView)
                        } action: { frame in
                            rowFrames[item.id] = frame
                        }
                        .id(item.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                scrollViewportHeight = height
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(panelState.currentDirectory.path)
            .onChange(of: panelState.selectedIndex) { oldIndex, newIndex in
                scrollRequestID += 1
                let requestID = scrollRequestID
                
                guard oldIndex != newIndex,
                      oldIndex >= 0,
                      oldIndex < panelState.filteredItems.count,
                      let selectedItemId = panelState.selectedItemId,
                      let previousFrame = rowFrames[panelState.filteredItems[oldIndex].id],
                      scrollViewportHeight > 0 else {
                    return
                }
                
                let movingDown = newIndex > oldIndex
                let movingUp = newIndex < oldIndex
                let rowHeight = max(previousFrame.height, 1)
                let reachedBottom = previousFrame.maxY + rowHeight > scrollViewportHeight
                let reachedTop = previousFrame.minY - rowHeight < 0
                
                guard (movingDown && reachedBottom) || (movingUp && reachedTop) else {
                    return
                }
                
                // A következő iránygombnál azonnal a megfelelő szélre gördítünk.
                let anchor: UnitPoint = movingDown ? .bottom : .top
                scrollToSelection(selectedItemId, using: proxy, anchor: anchor, requestID: requestID)
            }
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        VStack(spacing: 2) {
            // Kereső / Szűrő mező
            HStack(spacing: 4) {
                Text("Filter:")
                    .font(MCTheme.monoSmall)
                    .foregroundColor(MCTheme.directory)
                
                TextField("", text: $panelState.filterText)
                    .textFieldStyle(.plain)
                    .font(MCTheme.monoSmall)
                    .focused($isFilterFocused)
                    .onChange(of: panelState.shouldFocusFilter) { _, shouldFocus in
                        if shouldFocus {
                            isFilterFocused = true
                            panelState.shouldFocusFilter = false
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.4))
                
                if !panelState.filterText.isEmpty {
                    Button {
                        panelState.filterText = ""
                    } label: {
                        Text("×")
                            .font(MCTheme.monoBold)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
            
            // Összesítő statisztika
            HStack {
                Text(panelState.summaryText)
                    .font(MCTheme.monoSmall)
                    .foregroundColor(panelState.markedURLs.isEmpty ? .white : .yellow)
                Spacer()
                
                if let selected = panelState.selectedItem {
                    Text(selected.name)
                        .font(MCTheme.monoSmall)
                        .foregroundColor(MCTheme.directory)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(red: 0.0, green: 0.15, blue: 0.4))
        }
    }
    
    private func scrollToSelection(
        _ newId: String?,
        using proxy: ScrollViewProxy,
        anchor: UnitPoint,
        requestID: Int
    ) {
        guard let newId else { return }
        
        // A LazyVStack elemei csak a renderelési ciklus végén biztosan
        // elérhetők a ScrollViewReader számára. Animáció nélkül görgetünk,
        // hogy gyors billentyűismétlésnél ne torlódjanak fel régi célpontok.
        DispatchQueue.main.async {
            guard requestID == self.scrollRequestID,
                  self.panelState.selectedItemId == newId else {
                return
            }
            
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                proxy.scrollTo(newId, anchor: anchor)
            }
        }
    }
    
    private func toggleSort(by field: SortField) {
        if panelState.sortField == field {
            panelState.sortOrder.toggle()
        } else {
            panelState.sortField = field
            panelState.sortOrder = .ascending
        }
    }
}

// MARK: - Különálló FileRowView
struct FileRowView: View {
    let item: FileItem
    let isCursor: Bool
    let isMarked: Bool
    let isActivePanel: Bool
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    let onToggleMark: () -> Void
    
    @State private var lastClickTime: Date = Date.distantPast
    
    var body: some View {
        HStack(spacing: 6) {
            // Kijelölési kapcsoló (MC-ben a Space billentyű vagy kattintás)
            if !item.isParentDir {
                Button {
                    onToggleMark()
                } label: {
                    Text(isMarked ? "[*]" : "[ ]")
                        .font(MCTheme.monoSmall)
                        .foregroundColor(isCursor && isActivePanel ? .black : (isMarked ? .yellow : .gray))
                }
                .buttonStyle(.plain)
            } else {
                Text("   ")
                    .font(MCTheme.monoSmall)
            }
            
            // Fájlnév
            Text(item.name)
                .font(MCTheme.monoFont)
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Méret
            Text(FileService.shared.formatSize(bytes: item.size, isDirectory: item.isDirectory, isParent: item.isParentDir))
                .font(MCTheme.monoFont)
                .foregroundColor(isCursor && isActivePanel ? .black : (item.isDirectory ? MCTheme.directory : MCTheme.regularFile))
                .frame(width: 75, alignment: .trailing)
            
            // Dátum
            Text(item.isParentDir ? "" : FileService.shared.formatDate(item.modificationDate))
                .font(MCTheme.monoSmall)
                .foregroundColor(isCursor && isActivePanel ? .black : Color(white: 0.75))
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(rowBackgroundColor)
        .overlay(
            // Inaktív panelen vékony kerettel jelezzük az ottani kurzort
            isCursor && !isActivePanel ?
                RoundedRectangle(cornerRadius: 1).stroke(Color.cyan.opacity(0.7), lineWidth: 1) : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            let now = Date()
            if now.timeIntervalSince(lastClickTime) < 0.35 {
                onDoubleClick()
            } else {
                lastClickTime = now
                onSingleClick()
            }
        }
    }
    
    private var rowBackgroundColor: Color {
        if isCursor {
            return isActivePanel ? MCTheme.cursorBackground : Color(red: 0.0, green: 0.18, blue: 0.45)
        }
        return Color.clear
    }
    
    private var textColor: Color {
        if isCursor && isActivePanel {
            return MCTheme.cursorText
        }
        if isMarked {
            return MCTheme.selectedItem
        }
        switch item.category {
        case .parentDirectory, .directory:
            return MCTheme.directory
        case .executable:
            return MCTheme.executable
        case .archive:
            return MCTheme.archive
        case .image:
            return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .document:
            return Color(red: 0.9, green: 0.9, blue: 0.6)
        case .symlink:
            return MCTheme.symlink
        case .regular:
            return MCTheme.regularFile
        }
    }
}
