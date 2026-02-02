import Foundation

struct AIConfig: Codable, Identifiable {
    var id: UUID
    var name: String
    var apiKey: String
    var apiEndpoint: String
    var model: String
    var customPrompt: String
    var outputType: AIOutputType = .text
    var imageSize: AIImageSize = .size2K
    var aspectRatio: AIAspectRatio = .ratio3x4
    
    init(id: UUID = UUID(), name: String, apiKey: String, apiEndpoint: String, model: String, customPrompt: String, outputType: AIOutputType = .text, imageSize: AIImageSize = .size2K, aspectRatio: AIAspectRatio = .ratio3x4) {
        self.id = id
        self.name = name
        self.apiKey = apiKey
        self.apiEndpoint = apiEndpoint
        self.model = model
        self.customPrompt = customPrompt
        self.outputType = outputType
        self.imageSize = imageSize
        self.aspectRatio = aspectRatio
    }
    
    static let `default` = AIConfig(
        name: "默认配置",
        apiKey: "",
        apiEndpoint: "https://generativelanguage.googleapis.com/v1beta/models/",
        model: "gemini-pro",
        customPrompt: "请根据以下内容，帮我分析和总结：",
        outputType: .text
    )
    
    // UserDefaults 键
    private static let configsKey = "AIConfigsJSON"
    private static let selectedConfigIdKey = "SelectedConfigIdString"
    
    // 保存所有配置（使用 JSON 字符串）
    static func saveAll(_ configs: [AIConfig]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configs)
            if let jsonString = String(data: data, encoding: .utf8) {
                UserDefaults.standard.set(jsonString, forKey: configsKey)
                UserDefaults.standard.synchronize()
            }
        } catch {
            print("保存配置失败: \(error)")
        }
    }
    
    // 加载所有配置（从 JSON 字符串）
    static func loadAll() -> [AIConfig] {
        guard let jsonString = UserDefaults.standard.string(forKey: configsKey),
              let data = jsonString.data(using: .utf8) else {
            return [.default]
        }
        
        do {
            let decoder = JSONDecoder()
            let configs = try decoder.decode([AIConfig].self, from: data)
            return configs.isEmpty ? [.default] : configs
        } catch {
            print("加载配置失败: \(error)")
            return [.default]
        }
    }
    
    // 保存选中的配置ID（使用字符串）
    static func saveSelectedId(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: selectedConfigIdKey)
        UserDefaults.standard.synchronize()
    }
    
    // 加载选中的配置ID
    static func loadSelectedId() -> UUID? {
        guard let idString = UserDefaults.standard.string(forKey: selectedConfigIdKey) else {
            return nil
        }
        return UUID(uuidString: idString)
    }
    
    // 兼容旧版本：加载单个配置（已废弃）
    static func load() -> AIConfig {
        let configs = loadAll()
        if let selectedId = loadSelectedId(),
           let config = configs.first(where: { $0.id == selectedId }) {
            return config
        }
        return configs.first ?? .default
    }
}

// AI 服务类型
enum AIProvider: String, CaseIterable {
    case gemini = "Google Gemini"
    case openai = "OpenAI"
    case claude = "Anthropic Claude"
    case custom = "自定义"
    
    var defaultEndpoint: String {
        switch self {
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/models/"
        case .openai:
            return "https://api.openai.com/v1/chat/completions"
        case .claude:
            return "https://api.anthropic.com/v1/messages"
        case .custom:
            return ""
        }
    }
    
    var defaultModel: String {
        switch self {
        case .gemini:
            return "gemini-pro"
        case .openai:
            return "gpt-4"
        case .claude:
            return "claude-3-opus-20240229"
        case .custom:
            return ""
        }
    }
}

enum AIOutputType: String, CaseIterable, Codable {
    case text = "文本"
    case image = "图片"
}

enum AIImageSize: String, CaseIterable, Codable {
    case size1K = "1K"
    case size2K = "2K"
    case size4K = "4K"
    
    var apiValue: String {
        return self.rawValue
    }
}

enum AIAspectRatio: String, CaseIterable, Codable {
    case ratio1x1 = "1:1"
    case ratio3x4 = "3:4"
    case ratio4x3 = "4:3"
    case ratio16x9 = "16:9"
    case ratio9x16 = "9:16"
    
    var apiValue: String {
        return self.rawValue
    }
}
