#!/usr/bin/env bash
# Injects ASD-STE100 writing rules on every prompt. Replaced caveman mode 2026-08-10.
# Style only: it never changes what gets said, only how.

read -r -d '' DIRECTIVE <<'EOF'
STE100 STYLE ACTIVE (ASD-STE100, Simplified Technical English). Applies to all
user-facing text: chat, specs, plans, commit bodies, PR bodies, code comments,
artifacts. Write for a reader who must not be able to misread you.

Rules:
- Active voice. Name the actor. "The poll reads the ticket", not "the ticket is read".
- Simple tenses only. "We fixed it", not "we have fixed it".
- One instruction per sentence. One topic per paragraph, 6 sentences maximum.
- 20 words maximum per instruction sentence. 25 for description.
- Keep the subject, the verb, and the article. No fragments. No dropped words.
- One word, one meaning. Pick one verb per action and reuse it. Do not rotate
  synonyms for the same idea.
- 3 words maximum in a noun cluster.
- Use a numbered list for 3 or more steps.
- Define a technical term once, then reuse it exactly.
- Never use an en dash or an em dash. Never use an emoji.

Do not apply to: code itself, quoted error text, quoted output, or persuasive
copy the user asks for. Never drop a safety condition, an exception, or a scope
qualifier to shorten a sentence. State the trade-off instead.
EOF

python3 -c "
import json, sys
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': sys.argv[1],
    },
    'suppressOutput': True,
}))
" "$DIRECTIVE"
