# Lite Diary

一款简洁的 Flutter 日记应用，支持 Markdown 编辑、分组管理、标签系统、农历日历、那年今日回顾、搜索、LLM AI 助手、导出等功能。

## 功能

- **日历视图** — 传统月历，公历日期 + 农历小字
- **Markdown 编辑器** — 源码/预览双模式切换，工具栏快捷插入
- **翻页查看** — 左右滑动手势在同日/跨日条目间切换
- **分组管理** — 默认"日记/诗词"分组，支持自定义 CRUD
- **标签系统** — 多对多关键词标签，彩色底色 Chip
- **那年今日** — 往年同日日记随机回顾，可翻页浏览
- **即时搜索** — 按标题/全文/标签匹配实时筛选
- **LLM AI 助手** — OpenAI 兼容 API，流式对话，数据范围可控，智能分析提示词
- **导出** — 日记/诗稿/分组/全部四种导出，支持 ZIP 打包含图片
- **图片插入** — 支持从相册选图插入 Markdown
- **云端备份** — WebDAV 备份与恢复

## 运行

```bash
flutter pub get
dart run build_runner build    # 生成 drift/riverpod 代码
flutter run                     # 运行到已连接设备
flutter build apk --debug       # 构建 debug APK
```

## 技术栈

- **状态管理** — Riverpod
- **数据库** — drift (SQLite)
- **路由** — go_router
- **Markdown 渲染** — flutter_markdown
- **农历** — lunar
- **图片选择** — image_picker
- **HTTP** — http
- **云端** — webdav_client

## 项目结构

```
lib/
├── database/     # drift 数据库、表定义、DAO
├── providers/    # Riverpod Provider
├── pages/        # go_router 页面
│   ├── home/     # 首页、那年今日、分组
│   ├── content/  # 日记内容/编辑页
│   ├── llm/      # LLM 对话与配置
│   └── settings/ # 设置、导出、导入、云端
├── widgets/      # 可复用组件
├── services/     # LLM、农历、图片、导出、云端等服务
├── router.dart   # go_router 配置
└── main.dart     # 入口
```
