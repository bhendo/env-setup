function bh-tool-audit --description 'Audit brew packages and global mise tools for last use'
    set -l src (functions --details bh-tool-audit)
    set -l repo (path resolve $src | string replace -r '/configs/dotfiles/config/fish/functions/bh-tool-audit\.fish$' '')
    if not test -f $repo/scripts/tool-audit.py
        echo "bh-tool-audit: can't locate scripts/tool-audit.py from $src" >&2
        return 1
    end
    uv run $repo/scripts/tool-audit.py $argv
end
