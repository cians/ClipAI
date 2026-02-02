import SwiftUI
import Foundation

struct ClipboardHistoryView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var selectedItem: ClipItem?
    @State private var showClearAlert = false
    @State private var selectedTab: HistoryTab = .all
    
    private enum HistoryTab: String, CaseIterable, Identifiable {
        case all = "历史"
        case favorites = "收藏"
        
        var id: String { rawValue }
    }
    
    private var filteredHistory: [ClipItem] {
        switch selectedTab {
        case .all:
            return clipboardManager.textHistory
        case .favorites:
            return clipboardManager.favorites
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部
            HStack {
                Text("剪贴板历史")
                    .font(.headline)
                
                Spacer()
                
                Text("\(filteredHistory.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showClearAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("清空历史记录")
                .alert("确认清空", isPresented: $showClearAlert) {
                    Button("取消", role: .cancel) { }
                    Button("清空", role: .destructive) {
                        clipboardManager.clearHistory()
                    }
                } message: {
                    Text("确定要清空所有剪贴板历史记录吗？此操作不可恢复。")
                }
            }
            .padding()

            Picker("历史筛选", selection: $selectedTab) {
                ForEach(HistoryTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // 历史列表
            if filteredHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: selectedTab == .favorites ? "star" : "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text(selectedTab == .favorites ? "暂无收藏" : "暂无历史记录")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(selectedTab == .favorites ? "点击星标即可加入收藏夹" : "所有复制的文本会自动记录在这里")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredHistory, selection: $selectedItem) { item in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.preview)
                                .font(.body)
                                .lineLimit(2)
                                .help(fullContent(for: item))
                            
                            Text(formattedDate(item.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            clipboardManager.toggleHistoryFavorite(item)
                        }) {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .foregroundColor(item.isFavorite ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(item.isFavorite ? "取消收藏" : "加入收藏")
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                        clipboardManager.setClipboardAndCollect(item.content)
                    }
                    .contextMenu {
                        Button("复制到剪贴板并收集") {
                            clipboardManager.setClipboardAndCollect(item.content)
                        }
                        
                        Button(item.isFavorite ? "取消收藏" : "加入收藏") {
                            clipboardManager.toggleHistoryFavorite(item)
                        }
                        
                        Divider()
                        
                        Button("从历史中删除", role: .destructive) {
                            clipboardManager.removeHistoryItem(item)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func fullContent(for item: ClipItem) -> String {
        switch item.type {
        case .text:
            return item.content
        case .file, .image:
            return item.content
        }
    }
}

#Preview {
    ClipboardHistoryView()
        .environmentObject(ClipboardManager.shared)
        .frame(width: 300, height: 500)
}
