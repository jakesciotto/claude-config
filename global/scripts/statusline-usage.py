#!/usr/bin/env python3
"""Claude Code statusline: [token count] | [cost] | [context %].

stdin = statusline JSON payload. cost comes from the payload; token count and
context occupancy are derived from the session transcript JSONL (not in payload).
"""
import sys, json, os

# token count interpretation: cumulative tokens this session (all types).
# set to False to exclude cache_read (counts only "new" tokens processed).
INCLUDE_CACHE_READ = True


def fmt_tokens(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(int(n))


def context_limit(model_id):
    env = os.environ.get("CLAUDE_CTX_LIMIT")
    if env and env.isdigit():
        return int(env)
    return 1_000_000 if "1m" in model_id.lower() else 200_000


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("— | — | —")
        return

    cost = (data.get("cost") or {}).get("total_cost_usd")
    cost_str = f"${cost:.2f}" if isinstance(cost, (int, float)) else "$—"

    model_id = (data.get("model") or {}).get("id") or ""
    limit = context_limit(model_id)

    transcript = data.get("transcript_path")
    total = 0
    ctx = 0
    if transcript and os.path.exists(transcript):
        try:
            with open(transcript, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        rec = json.loads(line)
                    except Exception:
                        continue
                    msg = rec.get("message")
                    if not isinstance(msg, dict):
                        continue
                    usage = msg.get("usage")
                    if not isinstance(usage, dict):
                        continue
                    i = usage.get("input_tokens") or 0
                    o = usage.get("output_tokens") or 0
                    cc = usage.get("cache_creation_input_tokens") or 0
                    cr = usage.get("cache_read_input_tokens") or 0
                    total += i + o + cc + (cr if INCLUDE_CACHE_READ else 0)
                    if rec.get("type") == "assistant" or msg.get("role") == "assistant":
                        ctx = i + cc + cr
        except Exception:
            pass

    pct = min(100, round(100 * ctx / limit)) if limit else 0
    print(f"{fmt_tokens(total)} tok | {cost_str} | {pct}% ctx")


main()
