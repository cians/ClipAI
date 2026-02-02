import SwiftUI

struct SettingsView: View {
    @State private var configs: [AIConfig] = AIConfig.loadAll()
    @State private var selectedConfigId: UUID? = AIConfig.loadSelectedId()
    @State private var editingConfig: AIConfig?
    @State private var showingAddConfig = false
    @State private var showingSuccessAlert = false
    
    var selectedConfig: AIConfig? {
        configs.first(where: { $0.id == selectedConfigId })
    }
    
    var body: some View {
        TabView {
            // AI 配置管理
            VStack(spacing: 0) {
                // 配置列表
                List(selection: $selectedConfigId) {
                    ForEach(configs) { config in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(config.name)
                                    .font(.headline)
                                
                                Text("\(config.model) · \(config.outputType.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if config.id == selectedConfigId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedConfigId = config.id
                            AIConfig.saveSelectedId(config.id)
                        }
                        .contextMenu {
                            Button("编辑") {
                                editingConfig = config
                            }
                            
                            if configs.count > 1 {
                                Button("删除", role: .destructive) {
                                    deleteConfig(config)
                                }
                            }
                        }
                    }
                }
                .frame(height: 200)
                
                // 操作按钮
                HStack {
                    Button(action: {
                        // 创建一个新的配置实例，而不是使用默认配置
                        let newConfig = AIConfig(
                            id: UUID(),
                            name: "新配置",
                            apiKey: "",
                            apiEndpoint: AIProvider.gemini.defaultEndpoint,
                            model: AIProvider.gemini.defaultModel,
                            customPrompt: "请根据以下内容，帮我分析和总结：",
                            outputType: .text
                        )
                        editingConfig = newConfig
                        showingAddConfig = true
                    }) {
                        Label("添加配置", systemImage: "plus")
                    }
                    
                    Spacer()
                    
                    if let selected = selectedConfig {
                        Button("编辑") {
                            editingConfig = selected
                            showingAddConfig = false
                        }
                    }
                }
                .padding()
                
                Divider()
                
                // 配置详情
                if let config = selectedConfig {
                    Form {
                        Section(header: Text("配置信息")) {
                            LabeledContent("名称", value: config.name)
                            LabeledContent("模型", value: config.model)
                            LabeledContent("输出", value: config.outputType.rawValue)
                            LabeledContent("端点", value: config.apiEndpoint)
                            LabeledContent("API Key", value: config.apiKey.isEmpty ? "未设置" : "已设置")
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 600, height: 500)
            .tabItem {
                Label("AI 配置", systemImage: "brain")
            }
            .sheet(item: $editingConfig) { config in
                AIConfigEditorView(
                    config: config,
                    isNew: showingAddConfig,
                    onSave: { updatedConfig in
                        if showingAddConfig {
                            // 添加新配置
                            configs.append(updatedConfig)
                            // 设置为选中状态
                            selectedConfigId = updatedConfig.id
                            AIConfig.saveSelectedId(updatedConfig.id)
                        } else {
                            // 更新现有配置
                            if let index = configs.firstIndex(where: { $0.id == updatedConfig.id }) {
                                configs[index] = updatedConfig
                            }
                        }
                        // 保存所有配置
                        AIConfig.saveAll(configs)
                        // 通知主窗口刷新配置
                        NotificationCenter.default.post(name: NSNotification.Name("AIConfigUpdated"), object: nil)
                        // 重置状态
                        showingAddConfig = false
                        editingConfig = nil
                    },
                    onCancel: {
                        showingAddConfig = false
                        editingConfig = nil
                    }
                )
            }
            
            // 快捷键设置
            Form {
                Section(header: Text("全局快捷键")) {
                    HStack {
                        Text("切换剪贴板监听")
                        Spacer()
                        Text("⌘ + Shift + C")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    HStack {
                        Text("打开主窗口")
                        Spacer()
                        Text("⌘ + Shift + O")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Section(header: Text("说明")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 按 ⌘ + Shift + C 开启/关闭剪贴板监听")
                        Text("• 开启后，所有复制的内容会按时间顺序自动记录")
                        Text("• 支持文字、文件和图片（图片会保存为临时文件）")
                        Text("• 按 ⌘ + Shift + O 快速打开主窗口")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section(header: Text("权限")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("应用需要辅助功能权限来监听全局快捷键")
                        }
                        
                        Button("打开系统设置") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(width: 500, height: 400)
            .tabItem {
                Label("快捷键", systemImage: "keyboard")
            }
            
            // 关于
            Form {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("ClipAI")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("版本 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("智能内容聚合助手")
                            .font(.body)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("功能特性：")
                                .font(.headline)
                            
                            Text("• 全局快捷键收集内容")
                            Text("• 支持文本、文件和图片")
                            Text("• 一键发送给 AI 处理")
                            Text("• 支持多种 AI 服务")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .frame(width: 500, height: 400)
            .tabItem {
                Label("关于", systemImage: "info.circle")
            }
        }
        .alert("保存成功", isPresented: $showingSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("配置已保存")
        }
    }
    
    private func deleteConfig(_ config: AIConfig) {
        configs.removeAll { $0.id == config.id }
        if selectedConfigId == config.id {
            selectedConfigId = configs.first?.id
            if let newId = selectedConfigId {
                AIConfig.saveSelectedId(newId)
            }
        }
        AIConfig.saveAll(configs)
    }
}

// AI 配置编辑器视图
struct AIConfigEditorView: View {
    @State private var config: AIConfig
    @State private var selectedProvider: AIProvider = .gemini
    let isNew: Bool
    let onSave: (AIConfig) -> Void
    let onCancel: () -> Void
    
    init(config: AIConfig, isNew: Bool, onSave: @escaping (AIConfig) -> Void, onCancel: @escaping () -> Void) {
        _config = State(initialValue: config)
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(isNew ? "添加 AI 配置" : "编辑 AI 配置")
                    .font(.headline)
                
                Spacer()
                
                Button("取消") {
                    onCancel()
                }
            }
            .padding()
            
            Divider()
            
            // 表单
            Form {
                Section(header: Text("基本信息")) {
                    TextField("配置名称", text: $config.name)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section(header: Text("AI 服务提供商")) {
                    Picker("选择服务", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: selectedProvider) { newValue in
                        config.apiEndpoint = newValue.defaultEndpoint
                        config.model = newValue.defaultModel
                    }
                }
                
                Section(header: Text("API 配置")) {
                    SecureField("API Key", text: $config.apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("API 端点", text: $config.apiEndpoint)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("模型名称", text: $config.model)
                        .textFieldStyle(.roundedBorder)
                }

                Section(header: Text("输出类型")) {
                    Picker("输出类型", selection: $config.outputType) {
                        ForEach(AIOutputType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if config.outputType == .image {
                        Picker("图片尺寸", selection: $config.imageSize) {
                            ForEach(AIImageSize.allCases, id: \.self) { size in
                                Text(size.rawValue).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Picker("宽高比", selection: $config.aspectRatio) {
                            ForEach(AIAspectRatio.allCases, id: \.self) { ratio in
                                Text(ratio.rawValue).tag(ratio)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section(header: Text("默认提示词")) {
                    TextEditor(text: $config.customPrompt)
                        .frame(height: 80)
                        .font(.system(.body))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding()
            
            Divider()
            
            // 底部按钮
            HStack {
                Spacer()
                
                Button("保存") {
                    onSave(config)
                }
                .buttonStyle(.borderedProminent)
                .disabled(config.name.isEmpty || config.apiKey.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
}

#Preview {
    SettingsView()
}
