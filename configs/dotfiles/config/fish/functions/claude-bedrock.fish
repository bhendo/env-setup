function claude-bedrock --description "claude via AWS Bedrock regardless of project settings"
    claude --settings ~/.claude/settings-bedrock.json $argv
end
