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
    """剧情窗：屏幕上只出现剧情本身。

    - 不做任何横幅/状态输出；
    - `你>` 提示符不在这里打印，而由 agent.py 在**开始等待输入的那一刻**写进镜像文件，
      客户端只负责把它 tail 出来 —— 于是时机天然正确。
    - 本窗口读到的整行输入，用 tmux send-keys 注入会话（等同在该终端里敲）。
    """
    import select, time
    f = None
    while True:
        if f is None:
            if not os.path.exists(STORY_LOG):
                time.sleep(0.2); continue
            try:
                f = open(STORY_LOG, encoding="utf-8", errors="ignore")
            except OSError:
                time.sleep(0.3); continue
            data = f.read()
            if data:
                sys.stdout.write(data); sys.stdout.flush()
            continue
        try:
            rs, _, _ = select.select([sys.stdin, f], [], [], 0.3)
        except InterruptedError:
            continue
        except (OSError, ValueError):
            return
        for x in rs:
            if x is sys.stdin:
                line = sys.stdin.readline()
                if line == "":
                    return
                if line.strip():
                    err = _forward(line.rstrip("\n"))
                    if err:
                        sys.stderr.write("\n[剧情窗] 转发失败：%s\n" % err)
                        sys.stderr.flush()
            else:
                data = f.read()
                if data:
                    sys.stdout.write(data); sys.stdout.flush()


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
