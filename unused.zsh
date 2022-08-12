### 备份相关
# 存在两种同步方式
# dot 方式 : 主要用于同步系统、用户级别配置文件
#            使用拷贝方式加载到本地，兼容性好，需要通过判断时间戳手动更新
#            配置灵活，允许自定义用户、用户组，动态文件选择,同步后执行操作等
#            使用 github 作为中央仓库，需要提交，保留历史记录
# sync 方式: 主要用于用户级别大文件
#            使用链接方式加载到本地，占用空间小，更改文件可以实时更新
#            配置简单，文件必须可读，同步时文件的用户信息会被舍弃，权限标识会保留
#            端对端同步，能将每个 package 分配不同的对端同步策略中

# dot 方法使用 $FB_DOT_HOME 环境变量，通过 github 仓库进行同步
# 通过使用 dot_edit 配置 makefile 文件自定义同步位置更改用户等操作
if ((${+FB_DOT_HOME})) && [[ -d ${FB_DOT_HOME} ]] {
    dot_load(){
        local file=${1:A}
        zsh -c "cd ${FB_DOT_HOME} && make ${file:-install}"
    }

    dot_save(){
        zsh -c "cd ${FB_DOT_HOME} && make"
    }

    dot_edit(){
        "vim ${FB_DOT_HOME}/makefile"
    }
}
if ((${+FB_STOW_HOME})) && [[ -d ${FB_STOW_HOME} ]] {
    FB_STOW_HOME=${FB_STOW_HOME:A}
    FB_STOW_PARENT_DIR=${FB_STOW_HOME:h}
    [[ $FB_STOW_PARENT_DIR = '/' ]] && FB_STOW_PARENT_DIR=''

    FB_STOW_DEFAULT_PKG=default
    [[ ! -d $FB_STOW_HOME/$FB_STOW_DEFAULT_PKG ]] && mkdir $FB_STOW_HOME/$FB_STOW_DEFAULT_PKG
    FB_STOW_REMOVE_FOLDER=.remove


    # 获取当前文件的绝对路径，不展开超链接
    absolute_path(){
        realpath --no-symlinks $1
    }

    # 获取当前文件或超链接实际的绝对路径,只展开一级
    expand_link(){
        readlink $1 | xargs --no-run-if-empty realpath --no-symlinks
    }

    # Calculate relative path from A to B, returns true on success
    # Example: ln -s "$(relative_path "$from" "$to")" "$from"
    relative_path() {
        local from=$(absolute_path $1)
        local to=$(absolute_path $2)
        [[ ! -d $from ]] && from=${from:h}
        [[ ! -d $from ]] && echo dir $from not exits && return 1
        [[ ! -e $to ]] && echo file $to not exits && return 1

        to+=/
        local result
        while [[ $to != $from/* ]] {
            from=${from:h}
            result+=../
            if [[ $from == / ]] {
                result=${result%/} && break
            }
        }
        result+=${to#$from/}
        result=${result%/}
        echo ${result:-.}
    }

    sync_add(){
        [[ ! -e $1 ]] && echo file $1 not exits && return 1
        # 当前 item 的绝对路径
        local item_absolute=$(absolute_path $1)
        # 当前需要放在 stow 下的包名，默认放在 default 包下
        local package=${2:-$FB_STOW_DEFAULT_PKG}
        # 当前 item 相对于 $FB_STOW_PARENT_DIR 的路径
        # 同时也是 item 需要放置在 $FB_STOW_HOME/$package/ 的相对路径
        local item_resolved=${item_absolute#$FB_STOW_PARENT_DIR/}
        # 当前 $FB_STOW_REMOVE_FOLDER 不可操作
        [[ $item_resolved/ == $FB_STOW_REMOVE_FOLDER/* ]] \
            && echo changing $FB_STOW_REMOVE_FOLDER in $FB_STOW_HOME/ : Operation not permitted && return 1
        # 如果 item_resolved 的路径与原来的路径一致，说明该 item 不在该 stow 管理范围内
        [[ $item_absolute == $item_resolved ]] \
            && echo file $1 not in $FB_STOW_PARENT_DIR/ && return 1
        if [[ -L $item_absolute ]] {
            # 如果是符号链接：目标路径为当前 item 符号链接展开一级以后的路径
            local item_target=$(expand_link $item_absolute)
        } else {
            # 如果不是符号  ：目标路径为当前 item 在文件系统中的真实绝对路径
            local item_target=${item_absolute:A}
        }
        # 当前 item 的目标路径如果在 $FB_STOW_HOME/$package/ 下，如果位置相同不再重复添加并返回 1
        if [[ $item_target == $FB_STOW_HOME/*/$item_resolved ]] {
            # 链接指向的包的绝对路径
            local package_absolute=${item_target%$item_resolved}
            # 链接指向的包名
            local package_resolved=${package_absolute:t}
            if [[ package_resolved == $package ]] {
                echo file $1 already added
            } else {
                echo file $1 already added in $package_resolved, please use sync_remove first
            }
            return 1
        }
        # 当前 item 在 $FB_STOW_HOME 下的绝对路径
        local item_in=$FB_STOW_HOME/$package/$item_resolved
        # 如果 $FB_STOW_HOME/$package/ 下不存在 item 的父级目录则动态创建
        mkdir -p -- ${item_in:h}
        # FIXME 如果 $FB_STOW_HOME 中通过人为操作添加过对应文件,将出现异常
        if [[ -L $item_absolute ]] {
            # 尚未添加到 $FB_STOW_HOME 中的超链接 -> 执行添加后修改该超链接实际的地址为该链接的实际绝对路径
            # XXX 当前 stow 不支持管理绝对路径, 于是使用相对路径
            # @see https://github.com/aspiers/stow/issues/76
            ln -s $(relative_path $item_in $item_target) $item_in
            rm -f $item_absolute
        } elif [[ -d $item_absolute ]] {
            # 如果在其他 package 中存在相应文件夹的子文件将会出现嵌套,所以给予提示后停止执行
            for p ($FB_STOW_HOME/*) {
                [[ $p = $FB_STOW_HOME/$package ]] && continue
                [[ -e $p/$item_resolved ]] && echo file $1 already added in ${p:t}, please use sync_remove first && return 1
            }
            # 如果本 package 中存在相应文件夹的子文件先清空 item 中对应链接
            [[ -e $item_in ]] && (cd $FB_STOW_HOME && stow -D $package)
            rsync -a $item_absolute/ $item_in/
            rm -rf $item_absolute
        } else {
            mv $item_absolute $item_in
        }
        # 删除对应 package 中 remove 的相关文件
        local item_remove=$FB_STOW_HOME/$package/$FB_STOW_REMOVE_FOLDER/$item_resolved
        [[ -e $item_remove ]] && rm -rf $item_remove

        sync_load $package && echo $1 added
    }

    sync_remove(){
        [[ ! -e $1 ]] && echo file $1 not exits && return 1
        # 当前文件的绝对路径，可能是在 stow 中的 item 也可能是指向 item 的链接
        local file_absolute=$(absolute_path $1)
        # 当前 item 在 $FB_STOW_HOME 下的绝对路径
        local item_in
        if [[ $file_absolute != $FB_STOW_HOME/*/* ]] {
            if [[ ! -L $file_absolute ]] {
                item_in=${file_absolute:A}
                #echo file $1 not a link in $FB_STOW_HOME/ && return 1
            }
            # 如果是符号链接：在 stow 下绝对路径为当前 item 符号链接展开一级以后的路径
            item_in=$(expand_link $file_absolute)
        } else {
            # 如果不是符号  ：在 stow 下绝对路径为当前 item 在文件系统中的真实绝对路径
            if [[ -L $file_absolute ]] {
                item_in=$file_absolute
            } else {
                item_in=${file_absolute:A}
            }
        }
        # 当前 item 相对于 $FB_STOW_PARENT_DIR 的路径
        # 同时也是 item 需要放置在 $FB_STOW_HOME/$package/ 的相对路径
        local item_resolved=${item_in#$FB_STOW_HOME/*/}
        # 如果 item_resolved 的路径与原来的路径一致，说明该 item 没有被添加到 stow
        [[ $item_in == $item_resolved ]] \
            && echo file $1 not in "$FB_STOW_HOME/<package>" && return 1
        # 当前 $FB_STOW_REMOVE_FOLDER 不可操作
        [[ $item_resolved/ == $FB_STOW_REMOVE_FOLDER/* ]] \
            && echo changing $FB_STOW_REMOVE_FOLDER in $FB_STOW_HOME/ : Operation not permitted && return 1
        # 当前 item 的 package 的绝对路径
        local package_absolute=${item_in%$item_resolved}
        # 当前需要放在 stow 下的包名
        local package=${package_absolute:t}

        # 当前 item 在 $FB_STOW_HOME/$package/$FB_STOW_REMOVE_FOLDER 下删除占位符的绝对路径
        local item_remove=$FB_STOW_HOME/$package/$FB_STOW_REMOVE_FOLDER/$item_resolved

        if [[ -L $file_absolute || $file_absolute == $FB_STOW_HOME/*/* ]] {
            # 如果需要被删除的文件是文件夹,则将其中的所有文件放入 $FB_STOW_REMOVE_FOLDER
            echo $item_remove
            if [[ -d $item_in ]] {(
                cd $item_in
                for f (**/*(D)) {
                    new_file $item_remove/$f
                }
            )} else {
                new_file $item_remove
            }
            (cd $FB_STOW_HOME/$package && stow -D $FB_STOW_REMOVE_FOLDER -t ../..)
            ls -la $file_absolute
            # rm -f $item_absolute
            mv $item_in $file_absolute
        } else {
            # 如果需要被删除的文件的父目录是从 stow 建立的超链接则将文件取出后重新读取
            [[ -e $item_in ]] && (cd $FB_STOW_HOME && stow -D $package)
            mv $item_in $FB_STOW_PARENT_DIR/$item_resolved
            sync_load $package
        }
        echo $1 removed
    }

    sync_load(){(
        # 当前需要放在 stow 下的包名，默认放在 default 包下
        local package=${1:-$FB_STOW_DEFAULT_PKG}
        cd ${FB_STOW_HOME}
        # XXX stow 不支持多级目录作为 package，所以采用先进入一级目录并指定目标目录的方式
        [[ -d $package/$FB_STOW_REMOVE_FOLDER ]] && (
            cd $package
            stow -D $FB_STOW_REMOVE_FOLDER -t ../..
        )
        stow --ignore=\.stfolder --ignore=$FB_STOW_REMOVE_FOLDER -S $package
    )}
}
