#!/bin/sh
set -e

DEST="$1"
EXTRA_DIRS="${EXTRA_DIRS:-/usr/lib/perl5/vendor_perl}"

if [ -z "$DEST" ]; then
  echo "用法: $0 <目标目录>"
  echo "可通过环境变量 EXTRA_DIRS 传入额外复制的目录列表，空格分隔"
  exit 1
fi

echo ">>> 提取 Perl 模块到 $DEST"

# 复制 perl @INC 目录
perl -e 'print join("\n", @INC), "\n"' | while read -r dir; do
  [ -z "$dir" ] && continue
  if [ ! -d "$dir" ]; then
    echo ">>> 目录不存在，跳过 '$dir'"
    continue
  fi

  echo ">>> 复制目录 $dir -> $DEST$dir"
  mkdir -p "$DEST$dir"
  cp -a "$dir/." "$DEST$dir/"
done

# 复制额外目录列表
for extra_dir in $EXTRA_DIRS; do
  if [ -d "$extra_dir" ]; then
    echo ">>> 复制额外目录 $extra_dir -> $DEST$extra_dir"
    mkdir -p "$DEST$extra_dir"
    cp -a "$extra_dir/." "$DEST$extra_dir/"
  else
    echo ">>> 额外目录不存在，跳过 $extra_dir"
  fi
done

echo ">>> Perl 模块提取完成"
