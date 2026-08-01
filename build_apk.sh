#!/usr/bin/env bash
# 构建发布 APK，并注入 git describe 供关于页识别 preview/正式版。
# 标签提交上构建 → 正式版；其余提交（如 dev 分支）→ 关于页显示 preview 标识。
set -e
cd "$(dirname "$0")"
if [ -n "$(git status --porcelain)" ]; then
    echo "错误：工作区有未提交的改动，请先提交再构建（保证 short hash 反映确切构建状态）" >&2
    exit 1
fi
GIT_DESCRIBE=$(git describe --tags --always)
flutter build apk --release --dart-define=GIT_DESCRIBE="$GIT_DESCRIBE"
