CWD=$(pwd)

case "$CWD" in
    "$HOME"|"$HOME"/*)
        echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Trusted directory"}}'
        ;;
esac
exit 0
