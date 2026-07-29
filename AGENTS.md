# AGENTS.md — diary_lite

## 项目概述
Flutter 日记应用，主要运行场景为 Android 移动端。附带支持 Linux/Windows/Web，但非主要目标。

## 当前版本
v0.1.7 — 阶段一（本地明文 MVP）已基本完成。

---

## 已实现功能

| 功能 | 说明 |
|------|------|
| 日历视图 | 传统月历，公历日期 + 农历小字（初一显月名，其余只显日子） |
| 标题自动识别 | 无独立标题栏；正文首行 `#` 自动提取为标题 |
| Markdown 编辑器 | 源码/预览双模式切换，工具栏（加粗/斜体/列表/链接/图片） |
| 翻页查看 | 左右滑动手势在同日/跨日条目间切换，同日多条目显示翻条按钮 |
| 循环划页 | 首页三页（那年今日/日历/分组）无限循环划动 |
| 分组管理 | 默认"日记/诗词"分组 + 自定义 CRUD |
| 标签系统 | 多对多关键词标签，彩色底色 Chip，编辑模式可操作，预览模式可查看 |
| 那年今日 | 往年同日日记随机回顾，箭头翻页浏览 |
| 即时搜索 | 标题 + 全文 + 标签匹配，按回车显示结果 |
| 图片插入 | 从相册选图插入 Markdown，拷贝到应用私有目录 |
| 农历日历 | lunar package，干支纪年 + 农历月日 (1900-2100) |
| 诗稿导出 | 诗词分组导出排版诗稿 (干支标题 + 目录 + 正文)，含图片打包为 ZIP |
| 数据导出 | 日记/诗稿/分组/全部 四种导出方式，支持时间范围或全时段，含图片打包为 ZIP |
| 自动保存 | 1.5s 无操作自动保存，切后台/离开页面即时保存 |
| 主题色彩 | 8 色预设色板 + 深色模式，ColorSchemeBox 预览 |
| 导航栏控制 | 四个 Tab 开关，即时生效 |
| 首页顺序 | 三页（那年今日/日历/分组）拖拽排序，排首的为默认首页 |
| 日历年份 | 点击年份文字快速跳转年份 |
| 渲染设置 | 标题字号 (16-36px) / 正文字号 (12-28px) 滑动调整 |

---

## 数据模型

### Entry（日记条目）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int (PK) | 自增主键 |
| title | String? | 从正文首行 # 自动提取，无需手动输入 |
| date | DateTime | 标注日期 |
| content | String | Markdown 正文 |
| group_id | int (FK) | 所属分组 |
| created_at | DateTime | 创建时间 |
| updated_at | DateTime | 最后修改时间 |

### Group（分组）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int (PK) | 自增主键 |
| name | String | 分组名称，唯一 |
| sort_order | int | 排序权重 |

默认分组：**日记、诗词**。用户可自行创建、删除、重命名。

### Tag（标签）/ EntryTag / Image / Settings
- Tag: id, name (unique)
- EntryTag: entry_id, tag_id (多对多)
- Image: id, entry_id, file_path, original_name
- Settings: key, value (drift 表，存敏感配置)

---

## 导航与路由

底部导航栏（可配置显示/隐藏）：首页、内容、LLM、设置

首页为 PageView 三页循环划动：
| 页面 | 说明 |
|------|------|
| 那年今日 | 往年同日日记回顾 |
| 日历 | 月历视图（默认首页） |
| 分组 | 左侧分组列表 + 右侧日记列表 |

go_router 路由：
| 路径 | 页面 |
|------|------|
| `/` | 首页 PageView |
| `/content` | 内容页（默认今日） |
| `/content/date/:dateStr` | 指定日期内容 |
| `/entry/:id` | 指定条目 |
| `/entry/new` | 新建条目 |
| `/settings` | 设置主页 |
| `/settings/display` | 显示控制 |
| `/settings/about` | 关于 |
| `/settings/export` | 导出 |
| `/llm` | LLM（预留） |

---

## 存储架构

### 当前（阶段一 — 明文）
- 数据库：drift (SQLite)
- 非敏感设置：shared_preferences
- 图片：应用私有目录

### 计划中
- 云端存储 (WebDAV)

---

## 技术栈

| 用途 | 选型 |
|------|------|
| 状态管理 | Riverpod |
| 本地数据库 | drift |
| 路由 | go_router (StatefulShellRoute) |
| Markdown 渲染 | flutter_markdown |
| 非敏感设置 | shared_preferences |
| 农历 | lunar |
| 图片选择 | image_picker |

---

## 代码组织

```
lib/
├── database/     # drift 数据库、表定义、DAO
├── providers/    # Riverpod Provider
├── pages/        # go_router 页面
│   ├── home/     # 首页、那年今日、分组
│   ├── content/  # 日记内容/编辑页
│   ├── llm/      # LLM 对话（预留）
│   └── settings/ # 设置、导出、显示、关于
├── widgets/      # 可复用组件（日历/编辑器/标签/搜索/色板）
├── services/     # 农历/主题色/渲染设置/通知
├── router.dart   # go_router 配置
└── main.dart
```

## 常用命令

```bash
flutter pub get                           # 安装依赖
flutter run                               # 运行
flutter test                              # 测试 (48 tests)
flutter build apk --debug                 # 构建 debug APK
flutter analyze                           # 静态分析
dart run build_runner build               # 生成 drift/riverpod 代码
```

## 版本历史

| 版本 | 主要变更 |
|------|----------|
| 0.1.0 | 初始阶段一完整实现 |
| 0.1.1 | 修复设置-关于/热力图溢出 |
| 0.1.2 | 标题自动识别/分组选择/渲染字号/空内容不保存 |
| 0.1.3 | 配色可选/应用名/首页顺序/分组页/预览自动保存 |
| 0.1.4 | FlClash色板迁移/内容不丢失/分组跳转/名称修复 |
| 0.1.5 | 直读DB/导航栏即时生效/循环划页/日历调大 |
| 0.1.6 | 首页默认页/标签/搜索/导出合并 |
| 0.1.7 | 标签仅编辑模式/年份切换/删除热力图/搜索重写 |
