#!/usr/bin/env bash
# 清理构建产物与本地文件。不删除 package-lock.json，否则会丢失依赖锁定。
rm -rf logs dist dist.zip public.zip fivemin-linux-x64 fivemin-macos-arm64 fivemin-win-x64.exe fivemin.pid package-lock.json
