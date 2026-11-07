import SwiftUI
import AppKit

struct ContentView: View {
    @State private var appState = MCAppState()
    @State private var eventMonitor: Any? = nil
    @FocusState private var isWindowFocused: Bool
    
    var body: some View {
        ZStack {
            // Fő felület
            VStack(spacing: 0) {
                // Felső menüsor (Left  File  Command  Options  Right)
                TopMenuBarView(appState: appState)
                
                // Középső kétpaneles rész
                HStack(spacing: 2) {
                    FilePanelView(
                        side: .left,
                        panelState: appState.leftPanel,
                        isActive: appState.activePanel == .left,
                        onSelect: {
                            appState.activePanel = .left
                            isWindowFocused = true
                        },
                        onOpen: {
                            appState.openSelected()
                        }
                    )
                    
                    FilePanelView(
                        side: .right,
                        panelState: appState.rightPanel,
                        isActive: appState.activePanel == .right,
                        onSelect: {
                            appState.activePanel = .right
                            isWindowFocused = true
                        },
                        onOpen: {
                            appState.openSelected()
                        }
                    )
                }
                .padding(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                
                // Parancssor sáv (Prompt és státusz)
                CommandLineView(appState: appState)
                
                // Alsó F1 - F10 funkciógombsor
                FunctionBarView { fnNumber in
                    appState.triggerAction(fnNumber)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MCTheme.panelBackground)
            
            // Modális párbeszédablakok rétege (F1 Help, F3 View, F4 Edit, F5 Copy, F6 Move, F7 Mkdir, F8 Delete, Terminal)
            MCDialogsView(appState: appState)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(MCTheme.panelBackground)
        .focusable()
        .focused($isWindowFocused)
        .focusEffectDisabled()
        // SwiftUI szintű eseménykezelők (Azonnali válasz minden billentyűre)
        .onKeyPress(.downArrow) {
            guard appState.activeDialog == nil else { return .ignored }
            appState.currentActivePanel.moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard appState.activeDialog == nil else { return .ignored }
            appState.currentActivePanel.moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.return) {
            guard appState.activeDialog == nil else { return .ignored }
            if !appState.commandInput.trimmingCharacters(in: .whitespaces).isEmpty {
                appState.runCommand()
            } else {
                appState.openSelected()
            }
            return .handled
        }
        .onKeyPress(.tab) {
            guard appState.activeDialog == nil else { return .ignored }
            appState.switchPanel()
            return .handled
        }
        .onKeyPress(.space) {
            guard appState.activeDialog == nil else { return .ignored }
            if let item = appState.currentActivePanel.selectedItem, !item.isParentDir {
                appState.currentActivePanel.toggleMark(for: item.url)
                appState.currentActivePanel.moveSelection(by: 1)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if appState.activeDialog != nil {
                appState.activeDialog = nil
                isWindowFocused = true
                return .handled
            }
            return .ignored
        }
        .onAppear {
            activateAppAndFocus()
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: appState.activeDialog == nil) { _, isClosed in
            if isClosed {
                DispatchQueue.main.async {
                    isWindowFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isWindowFocused = true
                }
            }
        }
        .background(
            keyboardShortcutsHandler
        )
    }
    
    // MARK: - Indításkori fókusz és ablak aktiválás
    private func activateAppAndFocus() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.canBecomeKey }) ?? NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
            isWindowFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.keyWindow ?? NSApp.windows.first {
                window.makeKey()
            }
            isWindowFocused = true
        }
    }
    
    // MARK: - Robusztus ablakszintű billentyűzetfigyelő (NSEvent Monitor)
    private func setupKeyboardMonitor() {
        guard eventMonitor == nil else { return }
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return self.handleKeyDown(event: event)
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyDown(event: NSEvent) -> NSEvent? {
        let keyCode = event.keyCode
        
        // 1. Cmd + Y: Összehasonlítás Meld-del
        let isYKey = (keyCode == 16 || event.charactersIgnoringModifiers?.lowercased() == "y")
        if event.modifierFlags.contains(.command) && isYKey {
            appState.compareWithMeld()
            return nil
        }
        
        // 2. TAB (keyCode 48): Mindig panelváltás ha nincs felugró dialógus!
        if keyCode == 48 && appState.activeDialog == nil {
            NSApp.keyWindow?.makeFirstResponder(nil)
            appState.switchPanel()
            isWindowFocused = true
            return nil
        }
        
        // 3. Ha modális párbeszédablak van nyitva (F5, F6, F7, F8, F1, F3, F4, Terminal)
        if let activeDialog = appState.activeDialog {
            if keyCode == 53 { // Escape
                appState.activeDialog = nil
                isWindowFocused = true
                return nil
            }
            
            // Enter törlési megerősítésnél
            if keyCode == 36 || keyCode == 76 {
                if case .delete(let targets) = activeDialog {
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
                    isWindowFocused = true
                    return nil
                }
            }
            
            return event
        }
        
        // 4. Fő nézet: Fájllista irányítása
        // A fel-le nyilak és Enter mindig a fájllistát vezérlik ha a parancssor nem kapott kifejezetten enter parancsot
        switch keyCode {
        case 126: // Nyíl FEL
            appState.currentActivePanel.moveSelection(by: -1)
            return nil
            
        case 125: // Nyíl LE
            appState.currentActivePanel.moveSelection(by: 1)
            return nil
            
        case 36, 76: // Enter / Return
            if !appState.commandInput.trimmingCharacters(in: .whitespaces).isEmpty {
                appState.runCommand()
            } else {
                appState.openSelected()
            }
            return nil
            
        case 49: // Space -> Kijelölés / Taggelés váltása
            if let item = appState.currentActivePanel.selectedItem, !item.isParentDir {
                appState.currentActivePanel.toggleMark(for: item.url)
                appState.currentActivePanel.moveSelection(by: 1)
            }
            return nil
            
        // F1 - F10 Funkcióbillentyűk
        case 122: // F1
            appState.triggerAction(1)
            return nil
        case 120: // F2
            appState.triggerAction(2)
            return nil
        case 99:  // F3
            appState.triggerAction(3)
            return nil
        case 118: // F4
            appState.triggerAction(4)
            return nil
        case 96:  // F5
            appState.triggerAction(5)
            return nil
        case 97:  // F6
            appState.triggerAction(6)
            return nil
        case 98:  // F7
            appState.triggerAction(7)
            return nil
        case 100: // F8
            appState.triggerAction(8)
            return nil
        case 101: // F9 (PullDn / Switch panel)
            appState.switchPanel()
            return nil
        case 109: // F10
            appState.triggerAction(10)
            return nil
            
        default:
            return event
        }
    }
    
    // MARK: - Gyorsbillentyűk (Command + 1..9, 0 és Cmd + Y)
    @ViewBuilder
    private var keyboardShortcutsHandler: some View {
        Group {
            Button("") {
                appState.compareWithMeld()
            }
            .keyboardShortcut("y", modifiers: [.command])
            
            Button("") {
                if appState.activeDialog == nil {
                    appState.switchPanel()
                }
            }
            .keyboardShortcut(.tab, modifiers: [])
            
            ForEach(1...10, id: \.self) { num in
                let keyChar: KeyEquivalent = num == 10 ? "0" : KeyEquivalent(Character("\(num)"))
                Button("") {
                    if appState.activeDialog == nil {
                        appState.triggerAction(num)
                    }
                }
                .keyboardShortcut(keyChar, modifiers: [.command])
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }
}

#Preview {
    ContentView()
}
