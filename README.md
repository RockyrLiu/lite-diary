# Lite Diary

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

一款简洁的 Flutter 私人日记应用，支持 Markdown 编辑、分组管理、标签系统、农历日历、AI 分析（画像/情绪/建议/回顾）、WebDAV 云端备份等功能。

## 功能

### 日记

- **日历视图** — 传统月历，公历日期 + 农历小字，日期上标记日记数量；不可跳转未来日期
- **Markdown 编辑器** — 源码/预览双模式切换，支持图片插入、加粗/斜体/列表/代码/链接快捷工具栏
- **翻页浏览** — 左右滑动手势在同日/跨日条目间切换，带过渡动画
- **分组管理** — 默认"日记/诗词"分组，支持自定义 CRUD
- **标签系统** — 多对多关键词标签，输入补全建议
- **天气与地点** — 自动定位或手动填写，随内容即时保存
- **那年今日** — 往年同日日记回顾，可换篇，支持过滤筛选
- **即时搜索** — 按标题/全文匹配实时筛选
- **统计数据** — 首页展示总篇数、日记/诗词数量、总字数
- **底部导航栏自定义** — 显示/隐藏各 tab，即时生效
- **检查更新** — 关于页一键检测 GitHub 新版本

### AI 分析

- **智能对话** — OpenAI 兼容 API，流式输出，日期/分组/固定条目数据范围可控，支持自定义分析提示词（如内容摘要）
- **个人画像** — 基于年/季/月分期摘要合成长期画像，注入对话让 AI 更懂你；每月可更新
- **近期状态** — 近 7 天窗口增量更新，保持最新状态认知
- **情绪波动** — AI 按日打分（-5 ~ +5），曲线图 + 年度热力图（支持年份切换），可补算历史打分
- **AI 建议** — 基于近 7 天内容生成生活建议
- **AI 回顾** — 周/月/年度回顾报告
- **AI 看板** — Token 用量统计与费用估算

### 数据

- **导出/导入** — 支持按日记/诗稿/分组/全部导出为 ZIP（含图片），支持导入恢复
- **加密** — AES-GCM 加密导出/备份，保护隐私数据
- **云端备份** — WebDAV 备份与恢复

## 分支与版本约定

- **main** — 稳定发布版，对应 GitHub Release 标签（如 v0.3.1）
- **dev** — 最新功能（未经充分测试，可能存在未知问题）：`git checkout dev` 后自行构建

**版本约定**：每次发布正式版后，dev 分支立即将版本号升至下一个版本（如发布 v0.3.1 后 dev 为 0.3.2+17）。因此 dev 构建的版本号始终高于已发布版本，可据此区分构建；preview 构建不再递增 buildNumber，而是由 `build_apk.sh` 注入 git 标识，关于页显示 **preview** 徽标并标明构建来源提交（如 `preview(ef6529f)`），精确反映构建状态。

## 运行与构建

仓库代码通常领先于发布版本（发布节奏较慢，功能未经充分测试）。如需使用最新功能，请自行构建：

```bash
flutter pub get
dart run build_runner build    # 生成 drift / riverpod 代码
flutter run                     # 运行到已连接设备（调试）
./build_apk.sh                  # 构建发布 APK（产物在 build/app/outputs/flutter-apk/）
```

`build_apk.sh` 会注入 git 标识：在标签提交上构建为正式版，其余提交（如 dev 分支）构建的应用关于页带有 **preview** 标识。为保证徽标中的提交短哈希与实际构建状态一致，工作区存在未提交改动时脚本会直接报错，请先提交再构建。

## 技术栈

- **状态管理** — Riverpod
- **数据库** — drift (SQLite)
- **Markdown 渲染** — flutter_markdown
- **农历** — lunar
- **图表** — fl_chart
- **图片选择** — image_picker
- **定位** — geolocator / geocoding
- **网络** — http / webdav_client
- **加密** — crypto / encrypt
- **版本信息** — package_info_plus
- **主题** — Material 3 动态色彩

## 项目结构

```
lib/
├── database/     # drift 数据库、表定义、迁移
├── providers/    # Riverpod Provider
├── pages/
│   ├── home/     # 首页（日历、那年今日、分组）
│   ├── content/  # 日记内容/编辑页
│   ├── llm/      # AI 模块（对话、画像、状态、情绪、建议、回顾、看板）
│   └── settings/ # 设置、导出、导入、云端、外观、关于
├── widgets/      # 可复用组件
├── services/     # LLM、AI 分析、加密、云端、导出、农历、定位、主题
└── main.dart     # 入口
```

## 致谢

本项目部分设计灵感来自 [FlClash](https://github.com/chen08209/FlClash)，在此表示感谢。

## 协议

[GNU General Public License v3.0](LICENSE)
