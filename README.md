# Lite Diary

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

一款简洁的 Flutter 私人日记应用，支持 Markdown 编辑、分组管理、标签系统、农历日历、LLM AI 助手等丰富功能。

## 功能

- **日历视图** — 传统月历，公历日期 + 农历小字，日期上标记日记数量
- **Markdown 编辑器** — 源码/预览双模式切换，支持图片插入
- **翻页浏览** — 左右滑动手势在同日/跨日条目间切换，带过渡动画
- **分组管理** — 默认"日记/诗词"分组，支持自定义 CRUD
- **标签系统** — 多对多关键词标签，输入补全建议
- **那年今日** — 往年同日日记回顾，可换篇
- **即时搜索** — 按标题/全文匹配实时筛选
- **LLM AI 助手** — OpenAI 兼容 API，流式对话，数据范围可控，智能分析提示词
- **导出/导入** — 支持按日记/诗稿/分组/全部导出为 ZIP 含图片，支持加密导入
- **加密** — AES-GCM 加密导出，保护隐私数据
- **云端备份** — WebDAV 备份与恢复
- **统计数据** — 首页展示总篇数、日记/诗词数量、总字数
- **底部导航栏自定义** — 显示/隐藏各 tab，即时生效

## 运行

```bash
flutter pub get
dart run build_runner build    # 生成 drift / riverpod 代码
flutter run                     # 运行到已连接设备
flutter build apk --debug       # 构建 debug APK
```

## 技术栈

- **状态管理** — Riverpod
- **数据库** — drift (SQLite)
- **Markdown 渲染** — flutter_markdown
- **农历** — lunar
- **图片选择** — image_picker
- **网络** — http / webdav_client
- **加密** — crypto / encrypt
- **主题** — Material 3 动态色彩

## 项目结构

```
lib/
├── database/     # drift 数据库、表定义
├── providers/    # Riverpod Provider
├── pages/
│   ├── home/     # 首页（日历、那年今日、分组）
│   ├── content/  # 日记内容/编辑页
│   ├── llm/      # LLM 对话与配置
│   └── settings/ # 设置、导出、导入、云端、外观
├── widgets/      # 可复用组件
├── services/     # LLM、加密、云端、导出、农历、图片、导航、主题
└── main.dart     # 入口
```

## 致谢

本项目部分设计灵感来自 [FlClash](https://github.com/chen08209/FlClash)，在此表示感谢。

## 协议

[GNU General Public License v3.0](LICENSE)
