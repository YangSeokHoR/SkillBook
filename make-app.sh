#!/bin/bash
# SkillBook.app 빌드·설치 스크립트
# 사용법: ./make-app.sh  →  Release 빌드 후 /Applications/SkillBook.app 설치
set -e
cd "$(dirname "$0")"

xcodebuild -project SkillBook.xcodeproj -scheme SkillBook \
  -configuration Release -derivedDataPath build -quiet build

APP=build/Build/Products/Release/SkillBook.app

# /Applications에 설치 (실행 중이면 종료 후 교체)
pkill -x SkillBook 2>/dev/null || true
rm -rf /Applications/SkillBook.app
cp -R "$APP" /Applications/

echo "완료: /Applications/SkillBook.app 설치됨"
echo "실행: open /Applications/SkillBook.app"
