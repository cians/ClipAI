import SwiftUI

struct ClipItemView: View {
    let item: ClipItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标或缩略图
            if item.type == .image {
                // 显示图片缩略图
                if let nsImage = NSImage(contentsOfFile: item.content) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(iconColor)
                        .frame(width: 40, height: 40)
                }
            } else {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 30)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.body)
                    .lineLimit(2)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var iconName: String {
        switch item.type {
        case .text:
            return "doc.text"
        case .file:
            return "doc"
        case .image:
            return "photo"
        }
    }
    
    private var iconColor: Color {
        switch item.type {
        case .text:
            return .blue
        case .file:
            return .orange
        case .image:
            return .green
        }
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: item.timestamp, relativeTo: Date())
    }
}

#Preview {
    List {
        ClipItemView(item: ClipItem(type: .text, content: "这是一段示例文本内容，用于演示文本类型的显示效果"))
        ClipItemView(item: ClipItem(type: .file, content: "/Users/username/Documents/example.pdf"))
        ClipItemView(item: ClipItem(type: .image, content: "base64_image_data"))
    }
    .listStyle(.sidebar)
    .frame(width: 300)
}
