# ClipAI - macOS 智能内容聚合助手

一个开源的、集成AI的macOS剪切板助手。剪贴板与历史记录都是很敏感信息，使用非开源的软件总感觉不安全，因此萌生了自己搞一个开源的剪切板历史软件。它具备常见的剪切板历史和收藏功能，还可以通过剪切板实现跨应用的收集多段文字和图片，发给AI 处理。

## 功能特性

- 🎯 全局快捷键快速收集（默认：⌘ + Shift + C）
- 📝 多段文本收集与聚合
- 📁 支持添加文件、图片与混合内容
- 🤖 集成 AI 服务（支持 Gemini 等，可配置端点与模型）
- 💬 自定义 Prompt 指令与输出类型
- 📋 可选剪贴板监听，自动记录历史

## 项目结构

```
ClipAI/
├── ClipAI/
│   ├── App/
│   │   ├── ClipAIApp.swift          # 应用入口
│   │   └── AppDelegate.swift        # 应用委托
│   ├── Models/
│   │   ├── ClipItem.swift           # 内容项模型
│   │   └── AIConfig.swift           # AI 配置
│   ├── Services/
│   │   ├── HotKeyManager.swift      # 快捷键管理
│   │   ├── ClipboardManager.swift   # 剪贴板管理
│   │   └── AIService.swift          # AI 服务
│   ├── Views/
│   │   ├── MainWindow.swift         # 主窗口
│   │   ├── ClipItemView.swift       # 内容项视图
│   │   └── SettingsView.swift       # 设置视图
│   └── Resources/
│       └── Assets.xcassets
├── ClipAI.xcodeproj
└── README.md
```

## 技术栈

- Swift 5.9+
- SwiftUI
- Carbon (全局快捷键)
- Combine (响应式编程)

## 快速开始

### 1. 打开项目
```bash
open ClipAI.xcodeproj
```

### 2. 配置 AI API
在应用设置中配置你的 API 密钥：
- Gemini API Key
- 自定义 API 端点

### 3. 使用说明

1. 启动应用后，它会在菜单栏显示图标
2. 选择文字后按 ⌘ + Shift + C 添加到收集列表
3. 继续选择其他文字或拖入文件/图片
4. 点击菜单栏图标打开主界面
5. 选择 AI 配置并输入 Prompt
6. 点击“发送到 AI”，在右侧查看响应

### 4. 常用操作

- 开启/关闭剪贴板监听：按 ⌘ + Shift + C
- 快速打开主窗口：按 ⌘ + Shift + O
- 历史记录中点击条目可复制并加入收集
- 收藏历史条目可长期保留

## 权限要求

应用需要以下权限：
- ✅ 辅助功能 (Accessibility) - 用于全局快捷键
- ✅ 文件访问 - 用于读取选择的文件

## License

MIT
