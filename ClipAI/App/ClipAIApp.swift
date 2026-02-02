import SwiftUI

@main
struct ClipAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var clipboardManager = ClipboardManager.shared
    @StateObject private var hotKeyManager = HotKeyManager.shared
    
    var body: some Scene {
        // 菜单栏应用，不显示在 Dock 中
        Settings {
            SettingsView()
        }
    }
}
