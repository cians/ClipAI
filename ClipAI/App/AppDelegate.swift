import Cocoa
import SwiftUI
import ApplicationServices
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var mainWindow: NSWindow?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求通知权限
        requestNotificationPermissions()
        
        // 检查并请求辅助功能权限
        checkAccessibilityPermissions()
        
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 创建菜单栏图标
        setupMenuBar()
        
        // 初始化快捷键管理器
        HotKeyManager.shared.setup()
        
        // 监听快捷键触发事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotKeyPressed),
            name: .hotKeyPressed,
            object: nil
        )
        
        // 监听显示主窗口快捷键事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowWindowHotKey),
            name: .showWindowHotKeyPressed,
            object: nil
        )
        
        // 监听显示主窗口事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showMainWindow),
            name: .showMainWindow,
            object: nil
        )
        
        // 监听显示设置窗口事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings),
            name: NSNotification.Name("ShowSettings"),
            object: nil
        )
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "ClipAI")
            button.action = #selector(togglePopover)
        }
        
        // 创建菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开主窗口", action: #selector(showMainWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "设置", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func togglePopover() {
        showMainWindow()
    }
    
    @objc func handleHotKeyPressed() {
        // 快捷键按下时，切换剪贴板监听状态
        if ClipboardManager.shared.isMonitoring {
            ClipboardManager.shared.stopMonitoring()
            showNotification(title: "已停止监听", body: "剪贴板监听已关闭")
        } else {
            ClipboardManager.shared.startMonitoring()
            showNotification(title: "已开始监听", body: "此后剪贴板内容将自动记录")
        }
    }
    
    @objc func handleShowWindowHotKey() {
        // 打开主窗口的快捷键
        showMainWindow()
    }
    
    @objc func showMainWindow() {
        // 如果窗口不存在，创建新窗口
        if mainWindow == nil {
            let contentView = MainWindow()
                .environmentObject(ClipboardManager.shared)
            
            mainWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            mainWindow?.title = "ClipAI"
            mainWindow?.contentView = NSHostingView(rootView: contentView)
            mainWindow?.center()
            mainWindow?.delegate = self
            mainWindow?.isReleasedWhenClosed = false
        }
        
        // 显示窗口并调到最顶层
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showSettings() {
        // 创建独立的设置窗口
        if settingsWindow == nil {
            let contentView = SettingsView()
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "设置"
            settingsWindow?.contentView = NSHostingView(rootView: contentView)
            settingsWindow?.center()
            
            // 当窗口关闭时清空引用
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // 请求通知权限
    func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 显示通知
    func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知发送失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 检查辅助功能权限
    func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            // 显示警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "请在系统设置中授予 ClipAI 辅助功能权限，以启用全局快捷键功能。\n\n系统设置 → 隐私与安全性 → 辅助功能"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let hotKeyPressed = Notification.Name("hotKeyPressed")
    static let showWindowHotKeyPressed = Notification.Name("showWindowHotKeyPressed")
    static let showMainWindow = Notification.Name("showMainWindow")
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == mainWindow {
                mainWindow = nil
            }
        }
    }
}
