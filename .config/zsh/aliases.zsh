# Enhanced function to safely add abbreviations
safe_abbr() {
    local name="$1"
    local expansion="$2"

    # Check if abbr command is available
    if ! command -v abbr >/dev/null 2>&1; then
        return 1
    fi

    if abbr list 2>/dev/null | grep -q "^${name}="; then
        return 0
    fi

    abbr "$name=$expansion" > /dev/null 2>&1
    return $?
}

safe_abbr "g" "git"
safe_abbr "ga" "git add"
safe_abbr "gaa" "git add --all"
safe_abbr "gco" "git checkout"
safe_abbr "gcm" "git commit -m \"%\""
safe_abbr "gs" "git status"
safe_abbr "gsw" "git switch"
safe_abbr "gd" "git diff"
safe_abbr "gl" "git log --oneline"
safe_abbr "gps" "git push"
safe_abbr "gpl" "git pull"
safe_abbr "d" "docker"
safe_abbr "dc" "docker compose"
safe_abbr "dps" "docker ps"
safe_abbr "di" "docker images"
safe_abbr "k" "kubectl"
safe_abbr "kg" "kubectl get"
safe_abbr "kd" "kubectl describe"
safe_abbr "ka" "kubectl apply -f"
safe_abbr "ll" "eza -luUg -s created -r --time-style 'long-iso'"
safe_abbr "la" "eza -la"
safe_abbr "lt" "eza -T"
safe_abbr "vi" "nvim"
safe_abbr "m" "mise"
safe_abbr ".." "cd .."
safe_abbr "..." "cd ../.."
safe_abbr "~" "cd ~"
