#!/bin/sh
# 自动提取目标二进制文件的依赖库（含符号链接解析）到指定目录
# 支持通过环境变量和文件指定排除关键词
# 路径映射：
#   /bin    → /usr/bin
#   /sbin   → /usr/sbin
#   /lib    → /usr/lib
#   /lib64  → /usr/lib64

set -e

BIN="$1"
DEST="$2"
EXCLUDE_FILE=${EXCLUDE_FILE:-"/exclude-libs.txt"}
EXCLUDE_KEYWORDS=""

if [ -z "$BIN" ] || [ -z "$DEST" ]; then
  echo "用法: $0 <二进制路径> <目标目录>"
  echo "可选: 环境变量 EXCLUDE_LIBS=\"tsan gcc\"，或挂载 $EXCLUDE_FILE 文件"
  exit 1
fi

# 合并排除关键词
if [ -n "$EXCLUDE_LIBS" ]; then
  EXCLUDE_KEYWORDS="$EXCLUDE_LIBS"
fi

if [ -f "$EXCLUDE_FILE" ]; then
  FILE_KEYWORDS="$(grep -vE '^\s*#' "$EXCLUDE_FILE" | tr '\n' ' ')"
  EXCLUDE_KEYWORDS="$EXCLUDE_KEYWORDS $FILE_KEYWORDS"
fi

EXCLUDE_KEYWORDS="$(echo "$EXCLUDE_KEYWORDS" | tr -s ' ')"
echo ">>> 排除关键词: $EXCLUDE_KEYWORDS"

# 判断是否需要排除
is_excluded() {
  path="$1"
  name="$(basename "$path")"
  for excl in $EXCLUDE_KEYWORDS; do
    case "$path" in *"$excl"*|*"$excl") return 0 ;; esac
    case "$name" in *"$excl"*|*"$excl") return 0 ;; esac
  done
  return 1
}

# 路径映射函数 (查看是否为符号链接: ls -l /)
convert_target_path() {
  local path="$1"
  local rel="${path#/}"

  case "$rel" in
    bin/*)    rel="usr/bin/${rel#bin/}" ;;
    sbin/*)   rel="usr/sbin/${rel#sbin/}" ;;
    lib64/*)  rel="usr/lib64/${rel#lib64/}" ;;
    lib/*)    rel="usr/lib/${rel#lib/}" ;;
  esac

  echo "$DEST/$rel"
}

# 拷贝主程序
dest_path=$(convert_target_path "$BIN")
mkdir -p "$(dirname "$dest_path")"
cp -P "$BIN" "$dest_path"
chmod +x "$dest_path"
echo ">>> 拷贝主程序: $BIN → $dest_path"

# 拷贝依赖
ldd "$BIN" | awk '{print $3}' | grep -E '^/' | sort -u | while read -r lib; do
  [ -e "$lib" ] || continue
  if is_excluded "$lib"; then
    echo ">>> 跳过排除: $lib"
    continue
  fi

  target="$(convert_target_path "$lib")"
  if [ ! -e "$target" ]; then
    echo ">>> 拷贝依赖库: $lib → $target"
    mkdir -p "$(dirname "$target")"
    cp -P --preserve=links "$lib" "$target"
  fi

  if [ -L "$lib" ]; then
    resolved="$(readlink -f "$lib")"
    if is_excluded "$resolved"; then
      echo ">>> 跳过符号链接目标: $resolved"
      continue
    fi
    resolved_target="$(convert_target_path "$resolved")"
    if [ ! -e "$resolved_target" ]; then
      echo ">>> 拷贝符号链接目标: $resolved → $resolved_target"
      mkdir -p "$(dirname "$resolved_target")"
      cp -P --preserve=links "$resolved" "$resolved_target"
    fi
  fi
done
