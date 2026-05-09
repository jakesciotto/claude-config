INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
TRUSTED_DIRS=(
    "$HOME/github/**"
)
CWD=$(pwd)
for dir in "${TRUSTED_DIRS[@]}"; do
    if [[ "$CWD" == "$dir"* ]]; then
        echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Trusted directory"}}'
        exit 0
    fi
done
exit 0