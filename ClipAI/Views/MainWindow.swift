import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @StateObject private var aiService = AIService()
    @State private var customPrompt: String = AIConfig.load().customPrompt
    @State private var showingAlert = false
    @State private var aiConfigs: [AIConfig] = AIConfig.loadAll()
    @State private var selectedConfig: AIConfig = AIConfig.load()
    
    var body: some View {
        NavigationView {
            // 最左侧：剪贴板历史
            ClipboardHistoryView()
                .environmentObject(clipboardManager)
                .frame(minWidth: 260, idealWidth: 320)
            
            // 中间：收集的内容列表
            VStack(alignment: .leading, spacing: 0) {
                // 头部
                HStack {
                    Text("已收集内容")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle(isOn: $clipboardManager.isMonitoring) {
                        Image(systemName: clipboardManager.isMonitoring ? "record.circle.fill" : "record.circle")
                            .foregroundColor(clipboardManager.isMonitoring ? .red : .gray)
                    }
                    .toggleStyle(.button)
                    .help(clipboardManager.isMonitoring ? "停止监听剪贴板" : "开始监听剪贴板")
                    
                    Button(action: {
                        showingAlert = true
                    }) {
                        Image(systemName: "trash")
                    }
                    .help("清空所有内容")
                }
                .padding()
                
                Divider()
                
                // 内容列表
                if clipboardManager.items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("暂无内容")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("按 ⌘ + Shift + C 添加内容\n或开启剪贴板监听")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(clipboardManager.items) { item in
                            ClipItemView(item: item)
                                .contextMenu {
                                    Button("删除") {
                                        clipboardManager.removeItem(item)
                                    }
                                }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                clipboardManager.removeItem(clipboardManager.items[index])
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 250, idealWidth: 300)
            
            // 右侧：AI 交互区域
            VStack(spacing: 0) {
                // Prompt 输入区
                VStack(alignment: .leading, spacing: 8) {
                    Text("提示词")
                        .font(.headline)
                    
                    TextEditor(text: $customPrompt)
                        .font(.system(.body))
                        .frame(height: 80)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    HStack {
                        // AI 配置选择器
                        Menu {
                            ForEach(AIConfig.loadAll()) { config in
                                Button(action: {
                                    selectedConfig = config
                                    customPrompt = config.customPrompt
                                    AIConfig.saveSelectedId(config.id)
                                    reloadConfigs()
                                }) {
                                    HStack {
                                        Text(config.name)
                                        if config.id == selectedConfig.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Button("管理配置...") {
                                // 打开设置窗口
                                NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "brain")
                                Text(selectedConfig.name)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            Task {
                                let content = clipboardManager.getCombinedContent()
                                await aiService.sendRequest(
                                    content: content, 
                                    prompt: customPrompt,
                                    items: clipboardManager.items,
                                    config: selectedConfig
                                )
                            }
                        }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("发送到 AI")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(aiService.isLoading)
                        
                        if aiService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                        
                        Text("\(clipboardManager.items.count) 项内容")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Divider()
                
                // AI 响应区域
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI 响应")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !aiService.response.isEmpty || aiService.responseImageData != nil {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                if let data = aiService.responseImageData,
                                   let image = NSImage(data: data) {
                                    NSPasteboard.general.writeObjects([image])
                                } else {
                                    NSPasteboard.general.setString(aiService.response, forType: .string)
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                Text("一键复制")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    
                    ScrollView {
                        if let error = aiService.error {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            reloadConfigs()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AIConfigUpdated"))) { _ in
            reloadConfigs()
        }
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        } else if aiService.response.isEmpty && aiService.responseImageData == nil {
                            VStack(spacing: 20) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
                                Text("AI 响应将显示在这里")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                if let data = aiService.responseImageData,
                                   let nsImage = NSImage(data: data) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 480)
                                }
                                if !aiService.response.isEmpty {
                                    Text(aiService.response)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
            }
            .frame(minWidth: 320)
        }
        .alert("确认清空", isPresented: $showingAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clipboardManager.clearAll()
            }
        } message: {
            Text("确定要清空所有收集的内容吗？")
        }
    }
    
    private func reloadConfigs() {
        aiConfigs = AIConfig.loadAll()
        if let selectedId = AIConfig.loadSelectedId(),
           let config = aiConfigs.first(where: { $0.id == selectedId }) {
            selectedConfig = config
            customPrompt = config.customPrompt
        }
    }
}

#Preview {
    MainWindow()
        .environmentObject(ClipboardManager.shared)
        .frame(width: 800, height: 600)
}
