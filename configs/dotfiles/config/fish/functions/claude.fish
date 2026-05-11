function claude
    set -l bedrock_token (security find-generic-password -a $USER -s claude-code-bedrock -w 2>/dev/null)
    or return
    set -lx AWS_BEARER_TOKEN_BEDROCK $bedrock_token
    set -l firecrawl_key (security find-generic-password -a $USER -s claude-code-firecrawl -w 2>/dev/null)
    and set -lx FIRECRAWL_API_KEY $firecrawl_key
    command claude $argv
end
