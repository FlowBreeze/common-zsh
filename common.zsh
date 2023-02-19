### 基础函数
mkfile(){
    local file
    for file {
        mkdir -p -- "${file:h}" && true >> "$file" || return $?
    }
    return 0
}

# always follow symbolic links in SOURCE
bak() {
    if [[ -d $1 ]] {
      cp -rL "$1" "$1$(date +%Y-%m-%d_%H:%M).bak"
    } else {
      cp -r "$1" "$1$(date +%Y-%m-%d_%H:%M).bak"
    }
}

cdtemp () {
    cd $(mktemp -d)
}

no_history() {
    unset HISTORY HISTFILE HISTSAVE HISTZONE HISTORY HISTLOG
    export HISTFILE=/dev/null
    export HISTSIZE=0
    export HISTFILESIZE=0
}

repeat_until(){
    echo "Start trying [#]$*"
    until $*
    do
       sleep 1
       echo "Trying again [#]$*"
    done
}

### 代理相关
if ((${+FB_HTTP_PROXY})){
    with_proxy(){
        env \
        http_proxy=$FB_HTTP_PROXY \
        https_proxy=$FB_HTTP_PROXY \
        HTTP_PROXY=$FB_HTTP_PROXY \
        HTTPS_PROXY=$FB_HTTP_PROXY \
        zsh -c "$*"
    }

    export_proxy(){
        export http_proxy=$FB_HTTP_PROXY
        export https_proxy=$FB_HTTP_PROXY
        export HTTP_PROXY=$FB_HTTP_PROXY
        export HTTPS_PROXY=$FB_HTTP_PROXY
    }
}

