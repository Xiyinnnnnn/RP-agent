#!/usr/bin/env bash
# ============================================================
# RP-agent 一键安装
#   用法: bash <(curl -sL <raw-url>/install.sh)   或  bash install.sh
#   行为: 校验依赖 → 复制到 ~/RP-agent → 自检 → 可选创建桌面快捷方式 → API 探测
# ============================================================
set -u
export LC_ALL=zh_CN.UTF-8

REPO_URL="${RP_AGENT_REPO:-https://raw.githubusercontent.com/Xiyinnnnnn/RP-agent/main}"
DEST="$HOME/RP-agent"
FILES="agent.py story.py subagent.py play.py launch.sh RP-agent.desktop README.md DOC.md LICENSE install.sh"

GREEN='\e[32m'; YELLOW='\e[33m'; RED='\e[31m'; NC='\e[0m'
ok(){  echo -e "${GREEN}✓ $*${NC}"; }
warn(){ echo -e "${YELLOW}⚠ $*${NC}"; }
err(){ echo -e "${RED}✗ $*${NC}"; }

echo "===== RP-agent 安装 ====="
command -v python3 >/dev/null 2>&1 || { err "缺少 python3"; exit 1; }
ok "python3"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$SRC_DIR/agent.py" ]; then
  echo "  来源: $SRC_DIR"
  mkdir -p "$DEST"
  for f in $FILES; do [ -f "$SRC_DIR/$f" ] && install -m 644 "$SRC_DIR/$f" "$DEST/$f"; done
  chmod +x "$DEST/agent.py" "$DEST/story.py" "$DEST/subagent.py" "$DEST/play.py" "$DEST/launch.sh" 2>/dev/null
  for d in character worldbook rp; do
    [ -d "$SRC_DIR/$d" ] && { mkdir -p "$DEST/$d"; cp -rn "$SRC_DIR/$d/." "$DEST/$d/" 2>/dev/null || true; }
  done
else
  echo "  来源: $REPO_URL"
  mkdir -p "$DEST"
  for f in $FILES; do curl -sfL --max-time 60 -o "$DEST/$f" "$REPO_URL/$f" || { err "下载失败: $f"; exit 1; }; done
  chmod +x "$DEST/agent.py" "$DEST/story.py" "$DEST/subagent.py" "$DEST/play.py" "$DEST/launch.sh" 2>/dev/null
  for d in character worldbook rp; do
    mkdir -p "$DEST/$d"; curl -sfL --max-time 60 -o "$DEST/$d/目录.md" "$REPO_URL/$d/目录.md" || true
  done
  warn "远程模式仅核心文件；完整角色/世界书建议整仓 clone"
fi
ok "已安装到 $DEST"

python3 -c "import sys;sys.path.insert(0,'$DEST');import agent;agent.verify()" 2>/dev/null \
  && ok "资产校验通过" || warn "资产校验未通过"

echo ""
read -rp "创建桌面快捷方式 RP-agent GM? [Y/n] " ans
case "${ans:-Y}" in
  Y|y|"")
    if [ ! -f "$DEST/RP-agent.desktop" ]; then
      warn "缺少模板 $DEST/RP-agent.desktop，跳过"
    else
      for dir in "$HOME/Desktop" "$HOME/.local/share/applications"; do
        mkdir -p "$dir" 2>/dev/null || continue
        sed "s|@INSTALL_DIR@|$DEST|g" "$DEST/RP-agent.desktop" > "$dir/RP-agent.desktop"
        chmod +x "$dir/RP-agent.desktop" 2>/dev/null
      done
      update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
      kbuildsycoca6 --noincremental 2>/dev/null || true
      ok "桌面快捷方式已创建（模板: $DEST/RP-agent.desktop）"
    fi
    ;;
  *) warn "跳过桌面快捷方式（模板保留在 $DEST/RP-agent.desktop，可手动创建）" ;;
esac

echo ""
if curl -sf --max-time 2 "http://127.0.0.1:3050/v1/models" >/dev/null 2>&1; then
  ok "本地 API (3050) 已就绪"
else
  warn "本地 API 未检测到，运行前请配 RP_AGENT_API_URL/KEY/MODEL 或 $DEST/config.json"
fi

echo ""
echo "===== 完成 ====="
echo "  启动: python3 $DEST/play.py"
echo "  模板: $DEST/RP-agent.desktop 与 launch.sh 已在项目内"
