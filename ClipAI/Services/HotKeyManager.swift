import Foundation
import Carbon
import Cocoa

class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    
    private var hotKeyRef1: EventHotKeyRef?  // Cmd+Shift+C 添加内容
    private var hotKeyRef2: EventHotKeyRef?  // Cmd+Shift+O 打开主窗口
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    func setup() {
        // 注册全局快捷键：Cmd + Shift + C (添加内容)
        let result1 = registerHotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | shiftKey), id: 1, ref: &hotKeyRef1)
        print("Cmd+Shift+C registration result: \(result1)")
        
        // 注册全局快捷键：Cmd + Shift + O (打开主窗口)
        let result2 = registerHotKey(keyCode: UInt32(kVK_ANSI_O), modifiers: UInt32(cmdKey | shiftKey), id: 2, ref: &hotKeyRef2)
        print("Cmd+Shift+O registration result: \(result2)")
    }
    
    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32, ref: inout EventHotKeyRef?) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("CLAI".fourCharCodeValue)
        hotKeyID.id = id
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // 安装事件处理器（只在第一次时安装）
        if eventHandler == nil {
            InstallEventHandler(
                GetApplicationEventTarget(),
                { (nextHandler, theEvent, userData) -> OSStatus in
                    var hotKeyID = EventHotKeyID()
                    GetEventParameter(
                        theEvent,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )
                    
                    print("HotKey pressed with ID: \(hotKeyID.id)")
                    
                    // 根据 ID 发送不同的通知
                    if hotKeyID.id == 1 {
                        NotificationCenter.default.post(name: .hotKeyPressed, object: nil)
                    } else if hotKeyID.id == 2 {
                        NotificationCenter.default.post(name: .showWindowHotKeyPressed, object: nil)
                    }
                    
                    return noErr
                },
                1,
                &eventType,
                nil,
                &eventHandler
            )
        }
        
        // 注册热键
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        
        return status
    }
    
    deinit {
        if let hotKeyRef1 = hotKeyRef1 {
            UnregisterEventHotKey(hotKeyRef1)
        }
        if let hotKeyRef2 = hotKeyRef2 {
            UnregisterEventHotKey(hotKeyRef2)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

extension String {
    var fourCharCodeValue: Int {
        var result: Int = 0
        for char in self.utf8 {
            result = (result << 8) + Int(char)
        }
        return result
    }
}
