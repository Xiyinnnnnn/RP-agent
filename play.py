#!/usr/bin/env python3
import argparse, os, sys

BASE_DIR = os.path.expanduser("~/RP-agent")
sys.path.insert(0, BASE_DIR)

def main():
    ap = argparse.ArgumentParser(description="RP-agent 玩家 IO 端点")
    ap.add_argument("--quiet", action="store_true", help="隐藏 run 调试行，只显示 Story")
    args = ap.parse_args()
    if args.quiet:
        os.environ["RP_QUIET"] = "1"
    import agent
    agent.main()

if __name__ == "__main__":
    main()
