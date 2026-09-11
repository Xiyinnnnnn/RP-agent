#!/usr/bin/env python3
"""RP-agent 玩家 IO 端点。

  python3 play.py                单窗口（本进程直接跑 agent 主循环；无 GUI 时的回退）
  python3 play.py --quiet        同上，隐藏 [run]/思维链，只显示 Story
  python3 play.py --attach       剧情窗客户端：只显示 Story/选项，输入转发给 tmux 会话里的 agent.py

架构：RP 状态（State/History/Summary）只能由一个进程持有。
      所以窗口① = agent.py 会话本体；窗口② = 本文件的 --attach 客户端（只转发输入，不碰状态）。
"""
import argparse, os, subprocess, sys

BASE_DIR = os.path.expanduser("~/RP-agent")
sys.path.insert(0, BASE_DIR)

SESSION   = os.environ.get("RP_AGENT_TMUX", "rp-agent")
STORY_LOG = os.environ.get("RP_AGENT_STORY_LOG",
                           os.path.expanduser("~/.cache/rp-agent/story-window.log"))


def _session_alive():
    return subprocess.run(["tmux", "has-session", "-t", SESSION],
                          capture_output=True).returncode == 0


def _forward(line):
    """把剧情窗里的一行输入送进 tmux 会话（等同在那个终端里敲进去）。"""
    r = subprocess.run(["tmux", "send-keys", "-t", SESSION, "-l", line],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return (r.stderr or r.stdout or "tmux 调用失败").strip()[:150]
    subprocess.run(["tmux", "send-keys", "-t", SESSION, "Enter"], capture_output=True)
    return ""


def story_window():
    import threading, time
    print("─" * 46)
    print(" RP-agent · 剧情窗    输入会转交给 GM（agent.py 会话）")
    print("─" * 46, flush=True)
    if not _session_alive():
        print("⚠ 未找到会话 %r —— 请从桌面图标启动，或先跑 launch.sh。" % SESSION, flush=True)
    stop = threading.Event()

    def follow():
        f = None
        while not stop.is_set():
            if f is None:
                if not os.path.exists(STORY_LOG):
                    time.sleep(0.2); continue
                try:
                    f = open(STORY_LOG, encoding="utf-8", errors="ignore")
                    data = f.read()
                except OSError:
                    f = None; time.sleep(0.3); continue
                if data:
                    sys.stdout.write(data); sys.stdout.flush()
                continue
            data = f.read()
            if data:
                sys.stdout.write(data); sys.stdout.flush()
            else:
                time.sleep(0.15)

    threading.Thread(target=follow, daemon=True).start()
    while True:
        try:
            line = input("\n你> ")
        except (EOFError, KeyboardInterrupt):
            print(); break
        if not line.strip():
            continue
        err = _forward(line)
        print(("⚠ " + err) if err else "（已转交给 GM…）", flush=True)
    stop.set()


def main():
    ap = argparse.ArgumentParser(description="RP-agent 玩家 IO 端点")
    ap.add_argument("--quiet", action="store_true", help="隐藏 run 调试行，只显示 Story")
    ap.add_argument("--attach", action="store_true", help="剧情窗客户端（输入转发给 tmux 会话）")
    args = ap.parse_args()
    if args.attach:
        story_window(); return
    if args.quiet:
        os.environ["RP_QUIET"] = "1"
    import agent
    agent.main()


if __name__ == "__main__":
    main()
