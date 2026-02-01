#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-/home/koma/py39.tar.gz}"
DEST="${2:-/home/koma/miniconda3/envs}"
USER_NAME="$(id -un)"
GROUP_NAME="$(id -gn)"

echo "源文件: $SRC"
echo "目标目录: $DEST"

if [ ! -f "$SRC" ]; then
  echo "错误: 源文件不存在: $SRC" >&2
  exit 1
fi

# 显示压缩包顶层结构（前 30 行）
echo "-- 压缩包预览（前 30 行） --"
tar -tzf "$SRC" | sed -n '1,30p'

# 创建目标目录（如果不存在）
mkdir -p "$DEST"

# 解压（会覆盖同名文件）
echo "-- 开始解压 --"
if tar -xzf "$SRC" -C "$DEST"; then
  echo "解压完成。"
else
  echo "解压失败。若权限问题，请用 sudo 运行此脚本或先确保有写权限。" >&2
  exit 2
fi

# 设定归属为当前用户（若无权限会失败）
if chown -R "$USER_NAME:$GROUP_NAME" "$DEST" 2>/dev/null; then
  echo "已将 $DEST 的所属更改为 $USER_NAME:$GROUP_NAME"
else
  echo "未能更改所属（可能需要 sudo）。如果需要，请运行: sudo chown -R $USER_NAME:$GROUP_NAME $DEST" >&2
fi

# 校验信息
if command -v sha256sum >/dev/null 2>&1; then
  echo "-- 源文件 sha256: --"
  sha256sum "$SRC"
fi

echo
echo "完成。建议：在当前 shell 中运行下面命令以激活环境（如果解压包包含 env 文件夹）："
echo "  source ~/.bashrc && conda activate py39"

exit 0
