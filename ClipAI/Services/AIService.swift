import Foundation
import Combine

class AIService: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var response: String = ""
    @Published var responseImageData: Data?
    @Published var responseImageMimeType: String?
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    // 发送请求到 AI（支持图片）
    func sendRequest(content: String, prompt: String, items: [ClipItem], config: AIConfig) async {
        await MainActor.run {
            isLoading = true
            error = nil
            response = ""
            responseImageData = nil
            responseImageMimeType = nil
        }
        
        do {
            let result = try await callGeminiAPI(content: content, prompt: prompt, items: items, config: config)
            await MainActor.run {
                response = result.text ?? ""
                responseImageData = result.imageData
                responseImageMimeType = result.imageMimeType
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // 调用 Gemini API（支持多模态）
    private func callGeminiAPI(content: String, prompt: String, items: [ClipItem], config: AIConfig) async throws -> AIResult {
        
        guard !config.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        // 图片输出需要使用流式 API (streamGenerateContent)
        let apiMethod = config.outputType == .image ? "streamGenerateContent" : "generateContent"
        let urlString = "\(config.apiEndpoint)\(config.model):\(apiMethod)?key=\(config.apiKey)"
        guard let url = URL(string: urlString) else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建多模态内容
        var parts: [[String: Any]] = []
        
        // 先添加文本 prompt
        let fullPrompt = "\(prompt)\n\n文本内容:\n\(content)"
        parts.append(["text": fullPrompt])
        
        // 添加所有图片（转换为 base64）
        for item in items where item.type == .image {
            if let imageData = try? Data(contentsOf: URL(fileURLWithPath: item.content)),
               let base64String = imageData.base64EncodedString() as String? {
                parts.append([
                    "inline_data": [
                        "mime_type": "image/png",
                        "data": base64String
                    ]
                ])
                print("  📸 添加图片到请求: \(item.preview)")
            }
        }
        
        var requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": parts
                ]
            ]
        ]

        // 根据输出类型配置 generationConfig
        if config.outputType == .image {
            // 图片输出：使用 responseModalities 和 imageConfig
            requestBody["generationConfig"] = [
                "responseModalities": ["IMAGE", "TEXT"],
                "imageConfig": [
                    "imageSize": config.imageSize.apiValue,
                    "aspectRatio": config.aspectRatio.apiValue
                ]
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 打印请求体以便调试
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 请求体 (不含图片数据): \(config.outputType == .image ? "图片模式" : "文本模式")")
        }
        
        print("🚀 发送请求到 Gemini，包含 \(parts.count) 个部分，模型: \(config.model), API: \(apiMethod)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // 打印响应以便调试
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Gemini 原始响应长度: \(responseString.count) 字符")
            print("📥 Gemini 响应 (前2000字符): \(responseString.prefix(2000))")
        }
        
        // 解析响应
        var texts: [String] = []
        var imageData: Data?
        var imageMimeType: String?
        
        // 先尝试解析为单个 JSON 对象
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("📦 解析为单个 JSON 对象")
            parseGeminiResponse(json: json, texts: &texts, imageData: &imageData, imageMimeType: &imageMimeType)
        }
        // 再尝试解析为 JSON 数组
        else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            print("📦 解析为 JSON 数组，包含 \(jsonArray.count) 个元素")
            for (index, json) in jsonArray.enumerated() {
                print("📦 处理第 \(index) 个响应块")
                parseGeminiResponse(json: json, texts: &texts, imageData: &imageData, imageMimeType: &imageMimeType)
            }
        }
        // 最后尝试按行分割解析 NDJSON
        else if let responseString = String(data: data, encoding: .utf8) {
            print("📦 尝试解析为 NDJSON")
            let lines = responseString.components(separatedBy: "\n").filter { !$0.isEmpty }
            for (index, line) in lines.enumerated() {
                if let lineData = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                    print("📦 处理第 \(index) 行 NDJSON")
                    parseGeminiResponse(json: json, texts: &texts, imageData: &imageData, imageMimeType: &imageMimeType)
                }
            }
        }
        
        if texts.isEmpty && imageData == nil {
            print("⚠️ 未能解析出任何文本或图片数据")
            throw AIError.invalidResponse
        }
        
        return AIResult(
            text: texts.isEmpty ? nil : texts.joined(separator: "\n"),
            imageData: imageData,
            imageMimeType: imageMimeType
        )
    }
    
    // 解析 Gemini 响应 JSON
    private func parseGeminiResponse(json: [String: Any], texts: inout [String], imageData: inout Data?, imageMimeType: inout String?) {
        if let candidates = json["candidates"] as? [[String: Any]] {
            for candidate in candidates {
                if let content = candidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]] {
                    for part in parts {
                        if let text = part["text"] as? String {
                            texts.append(text)
                            print("📝 收到文本响应: \(text.prefix(100))...")
                        }
                        // 支持驼峰命名 (inlineData) 和蛇形命名 (inline_data)
                        let inlineData = part["inlineData"] as? [String: Any] ?? part["inline_data"] as? [String: Any]
                        if let inlineData = inlineData {
                            let mimeType = inlineData["mimeType"] as? String ?? inlineData["mime_type"] as? String
                            let base64Data = inlineData["data"] as? String
                            if let mimeType = mimeType, let base64Data = base64Data {
                                print("🖼️ 发现图片数据: \(mimeType), base64长度: \(base64Data.count)")
                                if let decodedData = Data(base64Encoded: base64Data) {
                                    imageData = decodedData
                                    imageMimeType = mimeType
                                    print("🖼️ 成功解码图片: \(mimeType), 大小: \(decodedData.count) bytes")
                                } else {
                                    print("⚠️ 图片 base64 解码失败")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 调用 OpenAI API (备用)
    private func callOpenAIAPI(prompt: String, config: AIConfig) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        guard let url = URL(string: config.apiEndpoint) else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let choices = json?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        throw AIError.invalidResponse
    }
}

struct AIResult {
    let text: String?
    let imageData: Data?
    let imageMimeType: String?
}

enum AIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请在设置中配置 API Key"
        case .invalidURL:
            return "无效的 API 地址"
        case .invalidResponse:
            return "无法解析 AI 响应"
        case .httpError(let statusCode, let message):
            return "HTTP 错误 \(statusCode): \(message)"
        }
    }
}
