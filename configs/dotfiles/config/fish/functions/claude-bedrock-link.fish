function claude-bedrock-link --description "symlink Bedrock settings into ./.claude/settings.local.json"
    set -l target .claude/settings.local.json
    if test -e $target; and not test -L $target
        echo "claude-bedrock-link: $target exists and is not a symlink; not overwriting" >&2
        return 1
    end
    mkdir -p .claude
    ln -sf ~/.claude/settings-bedrock.json $target
    echo "linked $target -> ~/.claude/settings-bedrock.json"
end
