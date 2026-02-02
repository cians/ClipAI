import Foundation

enum ClipItemType: String, Codable {
    case text
    case file
    case image
}

struct ClipItem: Identifiable, Codable, Hashable {
    let id: UUID
    let type: ClipItemType
    let content: String // 对于文本是内容本身，对于文件和图片是路径
    let timestamp: Date
    var isFavorite: Bool
    
    init(id: UUID = UUID(), type: ClipItemType, content: String, timestamp: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.type = type
        self.content = content
        self.timestamp = timestamp
        self.isFavorite = isFavorite
    }
    
    // 预览文本
    var preview: String {
        switch type {
        case .text:
            return content.count > 50 ? String(content.prefix(50)) + "..." : content
        case .file:
            return URL(fileURLWithPath: content).lastPathComponent
        case .image:
            return URL(fileURLWithPath: content).lastPathComponent
        }
    }
    
    // 自定义编码
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case content
        case timestamp
        case isFavorite
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        
        // 兼容旧版本的字符串类型
        if let typeString = try? container.decode(String.self, forKey: .type) {
            type = ClipItemType(rawValue: typeString) ?? .text
        } else {
            type = try container.decode(ClipItemType.self, forKey: .type)
        }
        
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isFavorite, forKey: .isFavorite)
    }
}
