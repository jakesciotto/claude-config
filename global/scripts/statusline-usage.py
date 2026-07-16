#!/usr/bin/env python3
"""Claude Code statusline: [token count] | [cost] | [context %]  [model] [effort]

stdin = statusline JSON payload. cost comes from the payload; token count and
context occupancy are derived from the session transcript JSONL (not in payload).
"""
import sys, json, os, re, shutil

# token count interpretation: cumulative tokens this session (all types).
# set to False to exclude cache_read (counts only "new" tokens processed).
INCLUDE_CACHE_READ = True

# ANSI color. disable with NO_COLOR env (https://no-color.org).
_USE_COLOR = not os.environ.get("NO_COLOR")

_ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def c(text, code):
    if not _USE_COLOR:
        return text
    return f"\033[{code}m{text}\033[0m"


def strip_ansi(s):
    return _ANSI_RE.sub("", s)


def term_width():
    env = os.environ.get("COLUMNS")
    if env and env.isdigit():
        return int(env)
    return shutil.get_terminal_size((120, 24)).columns


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


def model_short(model_id):
    """claude-sonnet-4-6 -> sonnet-4.6, claude-fable-5 -> fable-5"""
    if not model_id:
        return ""
    m = re.match(r"claude-([a-z]+)-(\d+)(?:-(\d{1,3}))?", model_id)
    if not m:
        return model_id
    family, major, minor = m.group(1), m.group(2), m.group(3)
    return f"{family}-{major}.{minor}" if minor else f"{family}-{major}"


def effort_display(effort):
    """Normalize effort label."""
    mapping = {"xhigh": "xhigh", "max": "max", "high": "high", "medium": "med", "low": "low"}
    return mapping.get((effort or "").lower(), effort or "")


def effort_color(effort):
    """ANSI code by effort tier."""
    tier = (effort or "").lower()
    if tier in ("max", "xhigh"):
        return "31"   # red
    if tier == "high":
        return "33"   # yellow
    if tier in ("medium", "med"):
        return "32"   # green
    return "36"       # cyan for low/unknown


def read_settings_effort():
    """Fall back to settings.json effortLevel if payload doesn't carry it."""
    path = os.path.expanduser("~/.claude/settings.json")
    try:
        with open(path) as f:
            return json.load(f).get("effortLevel", "")
    except Exception:
        return ""


def main():
    try:
        _main()
    except Exception:
        print("- | - | -")


def _main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("- | - | -")
        return

    if not isinstance(data, dict):
        print("- | - | -")
        return

    cost = (data.get("cost") or {}).get("total_cost_usd")
    cost_str = f"${cost:.2f}" if isinstance(cost, (int, float)) else "$-"

    # model_id: payload may have model as object {id:...} or bare string
    raw_model = data.get("model") or {}
    if isinstance(raw_model, dict):
        model_id = raw_model.get("id") or ""
    else:
        model_id = str(raw_model)
    limit = context_limit(model_id)

    # effort: payload carries effort as {"level": "..."}; also tolerate a bare
    # string or reasoning_effort key, then fall back to settings.json.
    effort_field = data.get("effort")
    if isinstance(effort_field, dict):
        effort_field = effort_field.get("level")
    effort_raw = (
        data.get("reasoning_effort")
        or effort_field
        or (raw_model.get("reasoning_effort") if isinstance(raw_model, dict) else None)
        or read_settings_effort()
    )

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

    # left side: tok | cost | ctx%
    pct_color = "32" if pct < 60 else ("33" if pct < 85 else "31")
    tok = c(f"{fmt_tokens(total)} tok", "36")
    cost_out = c(cost_str, "33")
    pct_out = c(f"{pct}% ctx", pct_color)
    sep = c("|", "90")
    left = f"{tok} {sep} {cost_out} {sep} {pct_out}"

    # right side: model + effort
    mname = model_short(model_id)
    edisplay = effort_display(effort_raw)
    right_parts = []
    if mname:
        right_parts.append(c(mname, "35"))          # magenta
    if edisplay:
        esep = c("|", "90")
        right_parts.append(f"{esep} {c(edisplay, effort_color(effort_raw))}")
    right = " ".join(right_parts)

    if not right:
        print(left)
        return

    # fullscreen TUI wraps the statusline in a bordered box, so usable content
    # width is a few columns narrower than $COLUMNS. reserve a right gutter.
    width = term_width()
    left_w = len(strip_ansi(left))
    right_w = len(strip_ansi(right))
    padding = max(2, width - left_w - right_w - 5)
    print(f"{left}{' ' * padding}{right}")


main()
