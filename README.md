# 日记 Lite (Diary Lite)

一款简洁的 Flutter 日记应用，支持 Markdown 编辑、分组管理、标签系统、农历日历、那年今日回顾、搜索、诗稿导出等功能。

## 功能

- **日历视图** — GitHub 风格热力图 + 传统月历（含农历小字）
- **Markdown 编辑器** — 源码/渲染双模式切换，工具栏快捷插入
- **翻页查看** — 左右滑动手势在同日/跨日条目间切换
- **分组管理** — 默认"日记/随笔/诗词"三分组，支持自定义 CRUD
- **标签系统** — 多对多关键词标签，支持自动补全
- **那年今日** — 往年同日日记随机回顾，可翻页浏览
- **即时搜索** — 首页顶部按标题/全文实时筛选
- **诗稿导出** — 诗词分组一键导出为排版诗稿
- **图片插入** — 支持从相册选图插入 Markdown

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

## 项目结构

```
lib/
├── database/     # drift 数据库、表定义、DAO
├── models/       # 数据模型（预留）
├── providers/    # Riverpod Provider
├── pages/        # go_router 页面
│   ├── home/     # 首页、那年今日、分组
│   ├── content/  # 日记内容/编辑页
│   ├── llm/      # LLM 对话（预留）
│   └── settings/ # 设置、导出
├── widgets/      # 可复用组件
├── services/     # 农历、图片、导出等服务
├── router.dart   # go_router 配置
└── main.dart     # 入口
```
