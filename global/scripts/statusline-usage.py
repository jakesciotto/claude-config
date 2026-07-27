#!/usr/bin/env python3
"""Claude Code statusline: usage on the left, model + effort right-justified.

stdin = statusline JSON payload. cost, model, effort and context occupancy come
from the payload; the cumulative token count is derived from the session
transcript JSONL (the payload only reports the current window).

Right-justification uses the COLUMNS env var, which Claude Code sets to the real
terminal width before running the script (v2.1.153+). tput/ioctl cannot work
here: stdout is a pipe and there is no controlling tty.
"""
import re, sys, json, os

# token count interpretation: cumulative tokens this session (all types).
# set to False to exclude cache_read (counts only "new" tokens processed).
INCLUDE_CACHE_READ = True

# ANSI color. disable with NO_COLOR env (https://no-color.org).
_USE_COLOR = not os.environ.get("NO_COLOR")


def c(text, code):
    if not _USE_COLOR:
        return text
    return f"\033[{code}m{text}\033[0m"


def fmt_tokens(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(int(n))


def context_limit(data):
    env = os.environ.get("CLAUDE_CTX_LIMIT")
    if env and env.isdigit():
        return int(env)
    size = (data.get("context_window") or {}).get("context_window_size")
    if isinstance(size, int) and size > 0:
        return size
    model_id = (data.get("model") or {}).get("id") or ""
    return 1_000_000 if "1m" in model_id.lower() else 200_000


def cumulative_tokens(transcript):
    if not transcript or not os.path.exists(transcript):
        return 0
    total = 0
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
                total += (
                    (usage.get("input_tokens") or 0)
                    + (usage.get("output_tokens") or 0)
                    + (usage.get("cache_creation_input_tokens") or 0)
                    + ((usage.get("cache_read_input_tokens") or 0) if INCLUDE_CACHE_READ else 0)
                )
    except Exception:
        pass
    return total


def context_pct(data, limit):
    cw = data.get("context_window") or {}
    pct = cw.get("used_percentage")
    if isinstance(pct, (int, float)):
        return min(100, round(pct))
    usage = cw.get("current_usage") or {}
    used = (
        (usage.get("input_tokens") or 0)
        + (usage.get("cache_creation_input_tokens") or 0)
        + (usage.get("cache_read_input_tokens") or 0)
    )
    return min(100, round(100 * used / limit)) if limit else 0


_ANSI = re.compile(r"\033\[[0-9;]*m")


def visible_len(s):
    return len(_ANSI.sub("", s))


def justify(left, right):
    """Pad between left and right so right sits at the terminal's right edge.

    Claude Code exports the real terminal width as COLUMNS. Notifications share
    the right end of this row, so a margin keeps them from overlapping; tune it
    with CLAUDE_STATUSLINE_MARGIN. Falls back to a plain separator when the
    width is unknown or too narrow to justify.
    """
    cols = os.environ.get("COLUMNS")
    if not (cols and cols.isdigit()):
        return f"{left} {c('|', '90')} {right}"

    # COLUMNS is the full terminal width, but the interface indents the status
    # row and reserves space at the right edge for notifications; overrunning it
    # gets the line truncated with an ellipsis. The reserve is undocumented, so
    # this is an empirical default -- raise it if the right segment still clips.
    margin_env = os.environ.get("CLAUDE_STATUSLINE_MARGIN", "")
    margin = int(margin_env) if margin_env.isdigit() else 6

    gap = int(cols) - margin - visible_len(left) - visible_len(right)
    if gap < 2:
        return f"{left} {c('|', '90')} {right}"
    return f"{left}{' ' * gap}{right}"


def model_label(data):
    model = data.get("model") or {}
    name = model.get("display_name") or model.get("id") or "?"
    return name.replace(" context", "")


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("— | — | —")
        return

    cost = (data.get("cost") or {}).get("total_cost_usd")
    cost_str = f"${cost:.2f}" if isinstance(cost, (int, float)) else "$—"

    limit = context_limit(data)
    pct = context_pct(data, limit)
    total = cumulative_tokens(data.get("transcript_path"))

    effort = (data.get("effort") or {}).get("level")

    # context %: green <60, yellow <85, red otherwise.
    pct_color = "32" if pct < 60 else ("33" if pct < 85 else "31")
    sep = c("|", "90")

    left = f" {sep} ".join([
        c(f"{fmt_tokens(total)} tok", "36"),   # cyan
        c(cost_str, "33"),                      # yellow
        c(f"{pct}% ctx", pct_color),
    ])

    right_parts = [c(model_label(data), "35")]  # magenta
    if effort:
        right_parts.append(c(effort, "90"))
    if data.get("fast_mode"):
        right_parts.append(c("fast", "36"))
    right = f" {sep} ".join(right_parts)

    print(justify(left, right))


main()
