import Foundation
import Cocoa
import Combine

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var items: [ClipItem] = []  // 已收集的内容（准备发送给AI）
    @Published var textHistory: [ClipItem] = []  // 全局剪贴板历史（独立存储）
    @Published var favorites: [ClipItem] = []  // 收藏（独立存储）
    @Published var isMonitoring: Bool = false  // 是否收集到 items
    
    private var lastChangeCount: Int
    private var historyTimer: Timer?  // 全局历史监听（一直运行）
    private let tempImageDirectory: URL
    
    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        
        // 创建临时图片目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipAI/Images", isDirectory: true)
        self.tempImageDirectory = tempDir
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        loadItems()
        loadTextHistory()
        loadFavorites()
        
        // 启动全局历史记录监听（一直运行）
        startGlobalHistoryMonitoring()
    }
    
    // 启动全局历史记录监听（一直运行）
    private func startGlobalHistoryMonitoring() {
        historyTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardForHistory()
        }
    }
    
    // 检查剪贴板变化（仅用于历史记录）
    private func checkClipboardForHistory() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // 只检查文本并添加到历史
            if let string = pasteboard.string(forType: .string), !string.isEmpty {
                addToHistory(string)
                
                // 如果开启了监听，也添加到收集列表
                if isMonitoring {
                    print("📋 监听模式开启，添加到收集列表")
                    captureCurrentClipboard()
                }
            }
        }
    }
    
    // 开始监听（收集内容到 items）
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        print("▶️ 开始收集剪贴板内容到列表")
    }
    
    // 停止监听
    func stopMonitoring() {
        isMonitoring = false
        print("⏸️ 停止收集剪贴板内容")
    }
    
    // 捕获当前剪贴板内容（添加到收集列表）
    func captureCurrentClipboard() {
        let pasteboard = NSPasteboard.general
        
        print("📋 捕获剪贴板内容到收集列表...")
        print("  - 可用类型: \(pasteboard.types ?? [])")
        
        // 优先检查图片（图片和文本可能同时存在）
        if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            print("  ✅ 发现图片")
            addImageItem(image)
            return
        }
        
        // 检查文件（必须有内容才返回）
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            print("  ✅ 发现文件: \(urls.count) 个")
            for url in urls {
                addFileItem(url)
            }
            return
        }
        
        // 检查文本
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            print("  ✅ 发现文本: \(string.prefix(50))...")
            addTextItem(string)
            return
        }
        
        print("  ❌ 未发现任何可识别内容")
    }
    
    // 添加文本项到收集列表
    func addTextItem(_ text: String) {
        // 避免重复添加
        if !items.contains(where: { $0.content == text && $0.type == .text }) {
            let item = ClipItem(type: .text, content: text)
            items.append(item)
            saveItems()
            print("  ✅ 已添加到收集列表")
        }
    }
    
    // 添加文本到历史记录（独立存储，一直运行）
    private func addToHistory(_ text: String) {
        // 检查是否已存在相同内容（避免重复）
        if !textHistory.contains(where: { $0.content == text }) {
            let isFav = favorites.contains(where: { $0.content == text && $0.type == .text })
            let historyItem = ClipItem(type: .text, content: text, isFavorite: isFav)
            textHistory.insert(historyItem, at: 0)  // 插入到最前面
            
            // 限制历史记录数量（保留最近 100 条）
            if textHistory.count > 100 {
                textHistory = Array(textHistory.prefix(100))
            }
            
            saveTextHistory()
            print("  📝 已添加到全局历史记录 (总计: \(textHistory.count) 条)")
        }
    }
    
    // 添加文件项
    func addFileItem(_ url: URL) {
        let item = ClipItem(type: .file, content: url.path)
        items.append(item)
        saveItems()
    }
    
    // 添加图片项
    func addImageItem(_ image: NSImage) {
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            
            // 生成唯一文件名
            let fileName = "image_\(UUID().uuidString).png"
            let fileURL = tempImageDirectory.appendingPathComponent(fileName)
            
            do {
                try pngData.write(to: fileURL)
                let item = ClipItem(type: .image, content: fileURL.path)
                items.append(item)
                saveItems()
                print("  ✅ 图片已保存: \(fileName)")
            } catch {
                print("  ❌ 保存图片失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 删除收集列表中的项
    func removeItem(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    // 删除历史记录中的项
    func removeHistoryItem(_ item: ClipItem) {
        textHistory.removeAll { $0.id == item.id }
        saveTextHistory()
    }

    // 切换历史记录收藏状态
    func toggleHistoryFavorite(_ item: ClipItem) {
        let isFav = favorites.contains(where: { $0.content == item.content && $0.type == item.type })
        if isFav {
            favorites.removeAll { $0.content == item.content && $0.type == item.type }
        } else {
            var favored = item
            favored.isFavorite = true
            favorites.insert(favored, at: 0)
        }
        syncHistoryFavorites()
        saveFavorites()
        saveTextHistory()
    }
    
    // 清空收集列表
    func clearAll() {
        items.removeAll()
        saveItems()
    }
    
    // 清空历史记录
    func clearHistory() {
        textHistory.removeAll()
        saveTextHistory()
        print("🗑️ 已清空剪贴板历史")
    }
    
    // 保存收集列表到 UserDefaults
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "ClipItems")
        }
    }
    
    // 从 UserDefaults 加载收集列表
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: "ClipItems"),
           let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) {
            items = decoded
        }
    }
    
    // 保存历史记录到 UserDefaults
    private func saveTextHistory() {
        if let encoded = try? JSONEncoder().encode(textHistory) {
            UserDefaults.standard.set(encoded, forKey: "ClipTextHistory")
        }
    }
    
    // 从 UserDefaults 加载历史记录
    private func loadTextHistory() {
        if let data = UserDefaults.standard.data(forKey: "ClipTextHistory"),
           let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) {
            textHistory = decoded
            syncHistoryFavorites()
        }
    }

    // 保存收藏到 UserDefaults（独立存储）
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: "ClipFavorites")
        }
    }

    // 从 UserDefaults 加载收藏
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "ClipFavorites"),
           let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) {
            favorites = decoded
            syncHistoryFavorites()
        }
    }

    // 同步历史记录中的收藏状态（不影响收藏本身）
    private func syncHistoryFavorites() {
        let favoriteSet = Set(favorites.map { "\($0.type.rawValue)::\($0.content)" })
        textHistory = textHistory.map { item in
            var updated = item
            let key = "\(item.type.rawValue)::\(item.content)"
            updated.isFavorite = favoriteSet.contains(key)
            return updated
        }
    }
    
    // 获取所有内容的合并文本（用于发送给 AI）
    func getCombinedContent() -> String {
        var result = ""
        
        for (index, item) in items.enumerated() {
            result += "--- 内容 \(index + 1) ---\n"
            
            switch item.type {
            case .text:
                result += item.content + "\n\n"
            case .file:
                // 尝试读取文件内容
                if let fileContent = try? String(contentsOfFile: item.content, encoding: .utf8) {
                    result += "文件: \(item.preview)\n"
                    result += fileContent + "\n\n"
                } else {
                    result += "文件: \(item.preview) (无法读取内容)\n\n"
                }
            case .image:
                result += "图片内容 (base64)\n\n"
            }
        }
        
        return result
    }
    
    // 将历史文本设置到剪贴板并添加到收集列表
    func setClipboardAndCollect(_ text: String) {
        // 设置到剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 更新 lastChangeCount 避免重复检测
        lastChangeCount = pasteboard.changeCount
        
        // 添加到收集列表（不添加到历史，因为已经在历史中了）
        addTextItem(text)
        
        print("📋 已将历史文本设置到剪贴板并添加到收集列表")
    }
}
