#!/bin/bash

ngx_default_params=("-g" "daemon off;")

non_empty_params=()
for param in "$@"; do
  # 使用 [[ ]] 进行更灵活的字符串比较
  # 包含至少一个非空白字符
  if [[ -n "$param" && "$param" =~ [^[:space:]] ]]; then
    non_empty_params+=("$param")
  fi
done

if [ ${#non_empty_params[@]} -gt 0 ]; then
  # 传入参数列表不为空
  nginx_use_params=("${non_empty_params[@]}")
else
  # 默认
  nginx_use_params=("${ngx_default_params[@]}")
fi

nginx -V
nginx -t
nginx "${nginx_use_params[@]}"
