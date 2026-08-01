#!/usr/bin/env bash
# 构建发布 APK，并注入 git describe 供关于页识别 preview/正式版。
# 标签提交上构建 → 正式版；其余提交（如 dev 分支）→ 关于页显示 preview 标识。
set -e
cd "$(dirname "$0")"
GIT_DESCRIBE=$(git describe --tags --always)
flutter build apk --release --dart-define=GIT_DESCRIBE="$GIT_DESCRIBE"
