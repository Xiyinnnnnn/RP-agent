#!/usr/bin/env bash
# ============================================================
# launch.sh —— RP-agent 桌面双击入口（双窗口）
#
#   窗口①  GM 控制台（本窗口）：tmux attach → 会话里的 python3 agent.py
#                              （全量输出：[run]/状态行/思维链/Story；可直接输入）
#   窗口②  剧情窗：konsole + python3 play.py --attach
#                              （只显示 Story/选项；在这里输入会转发给窗口①的会话）
#
#   唯一状态持有者 = tmux 会话里的那一个 agent.py 进程；窗口②只是 IO 客户端，
#   不碰 State/History/Summary（避免两个进程互写存档）。
#
#   回退：无 tmux/konsole/GUI 时 → 单窗口 python3 play.py --quiet（旧行为）
#   开关：RP_AGENT_1WIN=1 强制单窗口 | RP_AGENT_DRY=1 只打印计划不执行
# ============================================================
set -u
export LC_ALL=zh_CN.UTF-8

RP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
YELLOW=$(tput setaf 3 2>/dev/null); NC=$(tput sgr0 2>/dev/null)
SESSION="${RP_AGENT_TMUX:-rp-agent}"
STORY_LOG="${RP_AGENT_STORY_LOG:-$HOME/.cache/rp-agent/story-window.log}"

if [ ! -f "$RP_DIR/agent.py" ]; then
  echo "✗ 未找到 agent.py（$RP_DIR）"; read -rp "回车退出" _; exit 1
fi
if [ -z "${RP_AGENT_API_URL:-}" ] && [ ! -f "$RP_DIR/config.json" ]; then
  echo -e "${YELLOW}⚠ 未配置 API：设 RP_AGENT_API_URL/KEY/MODEL 或写 $RP_DIR/config.json${NC}"
fi
cd "$RP_DIR" || exit 1

dual=0
if [ "${RP_AGENT_1WIN:-}" != "1" ] \
   && command -v tmux >/dev/null 2>&1 && command -v konsole >/dev/null 2>&1 \
   && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
  dual=1
fi

if [ "${RP_AGENT_DRY:-}" = "1" ]; then
  echo "dual=$dual  SESSION=$SESSION  STORY_LOG=$STORY_LOG"
  if [ "$dual" = 1 ]; then
    echo "tmux kill-session -t $SESSION"
    echo "tmux new-session -d -s $SESSION -x 200 -y 50 \"cd '$RP_DIR' && RP_AGENT_STORY_LOG='$STORY_LOG' python3 '$RP_DIR/agent.py'\""
    echo "konsole --hold --workdir '$RP_DIR' -e python3 '$RP_DIR/play.py' --attach &   # 窗口② 剧情窗"
    echo "exec tmux attach -t $SESSION                                                  # 窗口① GM 控制台"
  else
    echo "exec python3 '$RP_DIR/play.py' --quiet                                        # 单窗口回退"
  fi
  exit 0
fi

if [ "$dual" = 1 ]; then
  mkdir -p "$(dirname "$STORY_LOG")" 2>/dev/null
  printf '\n===== RP-agent 剧情窗 =====\n（等待 GM 交付剧情…）\n' > "$STORY_LOG" 2>/dev/null || true
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  tmux new-session -d -s "$SESSION" -x 200 -y 50 \
      "cd '$RP_DIR' && RP_AGENT_STORY_LOG='$STORY_LOG' python3 '$RP_DIR/agent.py'"
  sleep 0.8
  # 窗口②：剧情窗（可输入，输入转发进会话）
  RP_AGENT_TMUX="$SESSION" RP_AGENT_STORY_LOG="$STORY_LOG" \
    konsole --hold --workdir "$RP_DIR" -e python3 "$RP_DIR/play.py" --attach >/dev/null 2>&1 &
  sleep 0.5
  # 窗口①：本窗口 = GM 控制台
  exec tmux attach -t "$SESSION"
else
  exec python3 "$RP_DIR/play.py" --quiet
fi
