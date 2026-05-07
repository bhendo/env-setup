# ~/.config/fish/functions/claude.fish
function claude
    set -l token (security find-generic-password -a $USER -s claude-code-bedrock -w 2>/dev/null)
    or return
    set -lx AWS_BEARER_TOKEN_BEDROCK $token
    command claude $argv
end
