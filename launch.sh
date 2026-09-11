#!/usr/bin/env bash
set -u
export LC_ALL=zh_CN.UTF-8

RP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
YELLOW=$(tput setaf 3 2>/dev/null); NC=$(tput sgr0 2>/dev/null)

if [ ! -f "$RP_DIR/agent.py" ]; then
  echo "✗ 未找到 agent.py（$RP_DIR）"
  read -rp "回车退出" _
  exit 1
fi

# API 由环境变量或 config.json 提供；未配置时 agent.py 会打印引导
if [ -z "${RP_AGENT_API_URL:-}" ] && [ ! -f "$RP_DIR/config.json" ]; then
  echo -e "${YELLOW}⚠ 未配置 API：设 RP_AGENT_API_URL/KEY/MODEL 或写 $RP_DIR/config.json${NC}"
fi

cd "$RP_DIR" || exit 1
exec python3 "$RP_DIR/play.py" --quiet
