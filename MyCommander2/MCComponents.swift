import SwiftUI

// MARK: - Felső Menüsor
struct TopMenuBarView: View {
    @Bindable var appState: MCAppState
    
    var body: some View {
        HStack(spacing: 8) {
            menuItem(title: "Left Panel") {
                Button("Reload Left Panel") { appState.leftPanel.refresh() }
                Divider()
                Button("Sort by Name") { setSort(panel: appState.leftPanel, field: .name) }
                Button("Sort by Size") { setSort(panel: appState.leftPanel, field: .size) }
                Button("Sort by Date") { setSort(panel: appState.leftPanel, field: .date) }
                Divider()
                Button(appState.leftPanel.showHidden ? "Hide Hidden Files" : "Show Hidden Files") {
                    appState.leftPanel.showHidden.toggle()
                    appState.leftPanel.refresh()
                }
            }
            
            menuItem(title: "File") {
                Button("View File (F3)") { appState.triggerAction(3) }
                Button("Edit File (F4)") { appState.triggerAction(4) }
                Button("Copy File(s) (F5)") { appState.triggerAction(5) }
                Button("Rename / Move File(s) (F6)") { appState.triggerAction(6) }
                Button("Create Directory (F7)") { appState.triggerAction(7) }
                Button("Delete File(s) (F8)") { appState.triggerAction(8) }
                Divider()
                Button("Compare with Meld (⌘Y)") { appState.compareWithMeld() }
                Divider()
                Button("Select / Tag All") { appState.currentActivePanel.selectAll() }
                Button("Clear Selection") { appState.currentActivePanel.clearMarks() }
            }
            
            menuItem(title: "Command") {
                Button("Compare with Meld (⌘Y)") { appState.compareWithMeld() }
                Button("Sync Opposite Panel Directory (⌘L)") {
                    appState.syncInactivePanelDirectory()
                }
                Button("Switch Active Panel (Tab / F9)") { appState.switchPanel() }
                Button("Reload Both Panels") {
                    appState.leftPanel.refresh()
                    appState.rightPanel.refresh()
                }
                Divider()
                Button("Go to Home Directory (~)") {
                    appState.currentActivePanel.navigateTo(directory: FileService.shared.defaultDirectory)
                }
                Button("Go to Root Directory (/)") {
                    appState.currentActivePanel.navigateTo(directory: URL(fileURLWithPath: "/"))
                }
            }
            
            menuItem(title: "Options") {
                Button(appState.currentActivePanel.showHidden ? "Hide Hidden Files" : "Show Hidden Files") {
                    appState.currentActivePanel.showHidden.toggle()
                    appState.currentActivePanel.refresh()
                }
                Divider()
                Button("Help / Shortcuts (F1)") {
                    appState.triggerAction(1)
                }
            }
            
            menuItem(title: "Right Panel") {
                Button("Reload Right Panel") { appState.rightPanel.refresh() }
                Divider()
                Button("Sort by Name") { setSort(panel: appState.rightPanel, field: .name) }
                Button("Sort by Size") { setSort(panel: appState.rightPanel, field: .size) }
                Button("Sort by Date") { setSort(panel: appState.rightPanel, field: .date) }
                Divider()
                Button(appState.rightPanel.showHidden ? "Hide Hidden Files" : "Show Hidden Files") {
                    appState.rightPanel.showHidden.toggle()
                    appState.rightPanel.refresh()
                }
            }
            
            Spacer()
            
            // Fókusz panel státusz jelző
            Text("Active: \(appState.activePanel.rawValue) Panel")
                .font(MCTheme.monoBold)
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(red: 0.0, green: 0.8, blue: 0.8))
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(red: 0.85, green: 0.85, blue: 0.85))
    }
    
    private func menuItem<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        Menu {
            content()
        } label: {
            Text(title)
                .font(MCTheme.monoBold)
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(white: 0.95))
                .cornerRadius(3)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    private func setSort(panel: PanelState, field: SortField) {
        if panel.sortField == field {
            panel.sortOrder.toggle()
        } else {
            panel.sortField = field
            panel.sortOrder = .ascending
        }
    }
}

// MARK: - Parancssor sáv (Prompt + Státuszüzenet)
struct CommandLineView: View {
    @Bindable var appState: MCAppState
    @FocusState private var isPromptFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Státuszüzenet
            HStack {
                Text(appState.statusMessage)
                    .font(MCTheme.monoSmall)
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                Spacer()
                Text("⌘Y: Meld  Tab: Switch  F1-F10")
                    .font(MCTheme.monoSmall)
                    .foregroundColor(Color.cyan)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(red: 0.0, green: 0.1, blue: 0.3))
            
            // Terminál beviteli sor (Prompt)
            HStack(spacing: 4) {
                Text("\(NSUserName())@Mac:\(appState.currentActivePanel.currentDirectory.lastPathComponent)$")
                    .font(MCTheme.monoBold)
                    .foregroundColor(MCTheme.promptPath)
                
                TextField("", text: $appState.commandInput)
                    .textFieldStyle(.plain)
                    .font(MCTheme.monoFont)
                    .foregroundColor(MCTheme.promptText)
                    .focused($isPromptFocused)
                    .onSubmit {
                        appState.runCommand()
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.black)
        }
    }
}

// MARK: - Alsó Funkciógombsor (F1 - F10)
struct FunctionBarView: View {
    let onAction: (Int) -> Void
    
    private let labels = [
        (1, "Help"),
        (2, "Menu"),
        (3, "View"),
        (4, "Edit"),
        (5, "Copy"),
        (6, "RenMov"),
        (7, "Mkdir"),
        (8, "Delete"),
        (9, "PullDn"),
        (10, "Quit")
    ]
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(labels, id: \.0) { num, label in
                Button {
                    onAction(num)
                } label: {
                    HStack(spacing: 2) {
                        Text("\(num)")
                            .font(MCTheme.monoBold)
                            .foregroundColor(MCTheme.fnKeyNumberText)
                            .padding(.horizontal, 4)
                            .background(MCTheme.fnKeyNumberBg)
                        
                        Text(label)
                            .font(MCTheme.monoBold)
                            .foregroundColor(MCTheme.fnKeyLabelText)
                            .padding(.horizontal, 3)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 22)
                    .background(MCTheme.fnKeyLabelBg)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
        .background(Color.black)
    }
}
