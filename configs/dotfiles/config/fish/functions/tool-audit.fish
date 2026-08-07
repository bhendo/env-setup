function tool-audit --description 'Audit brew packages and global mise tools for last use'
    set -l src (functions --details tool-audit)
    set -l repo (path resolve $src | string replace -r '/configs/dotfiles/config/fish/functions/tool-audit\.fish$' '')
    if not test -f $repo/scripts/tool-audit.py
        echo "tool-audit: can't locate scripts/tool-audit.py from $src" >&2
        return 1
    end
    uv run $repo/scripts/tool-audit.py $argv
end
