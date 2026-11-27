#!/bin/sh
# Builds dist/XiaoMount-<version>.zip for a manual CurseForge upload: one XiaoMount/ folder with
# only what the game loads plus license, readme and changelog. Runs the tests first.
set -eu
cd "$(dirname "$0")/.."
lua5.1 tests/logic.lua
version=$(sed -n 's/^## Version: *//p' XiaoMount.toc | tr -d '\r')
out="dist/XiaoMount-$version.zip"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/XiaoMount"
cp XiaoMount.toc Logic.lua XiaoMount.lua LICENSE README.md CHANGELOG.md "$stage/XiaoMount/"
mkdir -p dist
rm -f "$out"
(cd "$stage" && python3 -m zipfile -c "$OLDPWD/$out" XiaoMount)
echo "$out"
