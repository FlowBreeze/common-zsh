alias top="htop"

### 超级用户相关
# 切换到 root 的命令行
alias su='sudo \su'
alias chusr='chown'

### 系统服务相关
# 检查端口
alias check_port='lsof -i -P -n | grep '
# 检查进程
alias check_ps='ps -aux | grep '

### 系统操作相关
# 树状显示进程
alias ps='ps -f'
# 删除文件夹
alias rmf='rm -vrf'
# 拷贝移动可视化
alias cp='cp -v'
alias mv='mv -v'
# 清屏
alias cr='clear'


alias no-history='unset HISTORY HISTFILE HISTSAVE HISTZONE HISTORY HISTLOG; export HISTFILE=/dev/null; export HISTSIZE=0; export HISTFILESIZE=0'

bak(){
    cp $1  $1`date +%Y-%m-%d_%H:%M`.bak
}

with_proxy(){
    env http_proxy=$HTTP_PROXY https_proxy=$HTTP_PROXY zsh -c "$*"
}

