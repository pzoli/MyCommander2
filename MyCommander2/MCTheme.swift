import SwiftUI

/// Midnight Commander klasszikus színvilág és stílus elemek
struct MCTheme {
    // Alapszínek (Klasszikus Norton / Midnight Commander paletta)
    static let panelBackground = Color(red: 0.0, green: 0.0, blue: 0.65)       // Sötétkék (#0000a6)
    static let panelBorder = Color(red: 0.0, green: 0.75, blue: 0.75)          // Cián kék (#00b8b8)
    static let activeBorder = Color(red: 0.35, green: 1.0, blue: 1.0)          // Élénk cián (#55ffff)
    
    // Szövegszínek
    static let regularFile = Color(red: 0.9, green: 0.9, blue: 0.9)            // Világosszürke / fehér
    static let directory = Color(red: 0.35, green: 1.0, blue: 1.0)             // Világos cián (#55ffff)
    static let executable = Color(red: 0.35, green: 1.0, blue: 0.35)           // Világoszöld (#55ff55)
    static let archive = Color(red: 1.0, green: 0.45, blue: 0.9)              // Világos magenta/pink
    static let symlink = Color(red: 1.0, green: 1.0, blue: 0.35)              // Világossárga
    static let selectedItem = Color(red: 1.0, green: 1.0, blue: 0.2)           // Sárga kijelölés
    
    // Kurzor és kiválasztás színek
    static let cursorBackground = Color(red: 0.0, green: 0.65, blue: 0.65)     // Cián kurzor háttér
    static let cursorText = Color.black                                        // Fekete szöveg a kurzoron
    static let inactiveCursorBackground = Color(red: 0.15, green: 0.25, blue: 0.5) // Inaktív kurzor
    
    // Menü és funkciógombok
    static let topMenuBarBg = Color(red: 0.0, green: 0.5, blue: 0.5)           // Cián/szürkés felső menü
    static let topMenuText = Color.black
    static let topMenuShortcut = Color(red: 0.9, green: 0.9, blue: 0.0)       // Sárga gyorsbillentyű
    
    static let fnKeyNumberBg = Color.black
    static let fnKeyNumberText = Color.white
    static let fnKeyLabelBg = Color(red: 0.0, green: 0.5, blue: 0.5)          // Cián funkciógomb háttér
    static let fnKeyLabelText = Color.black
    
    static let promptText = Color.white
    static let promptPath = Color(red: 0.35, green: 1.0, blue: 1.0)
    
    // Betűtípusok
    static let monoFont = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let monoBold = Font.system(size: 12, weight: .bold, design: .monospaced)
    static let monoHeader = Font.system(size: 13, weight: .bold, design: .monospaced)
    static let monoSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
}
