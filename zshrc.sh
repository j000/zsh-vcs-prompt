###############################################################################
#
#  VCS INFO
#
#  How to install
#     source path/to/zshrc.sh
#
#     # an example prompt
#     RPROMPT='$(vcs_info)'
#
###############################################################################

# Using python script (gitstatus.py)
if [ -z "$ZSH_VCS_PROMPT_USING_PYTHON" ];then
    ZSH_VCS_PROMPT_USING_PYTHON='true'
fi

#
# Default values for the appearance of the prompt.
# Configure at will.
#
# git status symbol
VCS_SIGIL="∇ "
VCS_STAGED_SIGIL="● "
VCS_UNSTAGED_SIGIL="✚ "
VCS_UNTRACKED_SIGIL="… "
VCS_CONFLICTS_SIGIL="✖ "
VCS_STASHED_SIGIL="⚑"
VCS_CLEAN_SIGIL="✔ "
VCS_AHEAD_SIGIL="↑ "
VCS_BEHIND_SIGIL="↓ "

# color settings
VCS_NAME_COLOR="%{%B%F{yellow}%}"
VCS_NAME_COLOR_USING_PYTHON="%{%F{yellow}%}"
VCS_BRANCH_COLOR="%{%B%F{red}%}"
VCS_ACTION_COLOR="%{%B%F{red}%}"
VCS_REMOTE_COLOR=
VCS_STAGED_COLOR="%{%F{blue}%}"
VCS_UNSTAGED_COLOR="%{%F{yellow}%}"
VCS_UNTRACKED_COLOR=
VCS_STASHED_COLOR="%{%F{cyan}%}"
VCS_CLEAN_COLOR="%{%B%F{green}%}"


# Exe directory
ZSH_VCS_PROMPT_DIR=$(cd $(dirname $0) && pwd)

#
# VCS_INFO
#  http://zsh.sourceforge.net/Doc/Release/User-Contributions.html#SEC273
#  https://github.com/olivierverdier/zsh-git-prompt
#  http://d.hatena.ne.jp/mollifier/20100906/p1
#  http://d.hatena.ne.jp/yuroyoro/20110219/1298089409
#  http://d.hatena.ne.jp/pasela/20110216/git_not_pushed
#  http://liosk.blog103.fc2.com/blog-entry-209.html
#
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git svn hg bzr

# formatsのプレースホルダの最大値
zstyle ':vcs_info:*' max-exports 7

# hg で check-for-changes を有効にするために必要
zstyle ':vcs_info:hg:*' get-revision true
zstyle ':vcs_info:hg:*' use-simple true

#
# フォーマットに指定できる変数
#   %s : The VCS in use (git, hg, svn, etc.).
#   %b : Information about the current branch.
#   %a : An identifier that describes the action. Only makes sense in actionformats.
#   %r : The repository name. If %R is /foo/bar/repoXY, %r is repoXY.
#   %c : The string from the stagedstr style if there are staged changes in the repository.
#   %u : The string from the unstagedstr style if there are unstaged changes in the repository.
#

# 左から順番に、vcs_info_msg_{n}_ という変数に格納される
zstyle ':vcs_info:*' formats '(%s)-[%b]'
zstyle ':vcs_info:*' actionformats '(%s)-[%b|%a]'
zstyle ':vcs_info:(svn|bzr):*' branchformat '%b:%r'

autoload -Uz is-at-least
if is-at-least 4.3.10; then
    # zshが4.3.10以上の場合
    zstyle ':vcs_info:git:*' check-for-changes true
    zstyle ':vcs_info:git*:*' stagedstr "${VCS_STAGED_COLOR}${VCS_STAGED_SIGIL}"
    zstyle ':vcs_info:git*:*' unstagedstr "${VCS_UNSTAGED_COLOR}${VCS_UNSTAGED_SIGIL}"
    zstyle ':vcs_info:git:*' formats '%s' '${VCS_BRANCH_COLOR}%b%{${reset_color}%}' '%c' '%u'
    zstyle ':vcs_info:git:*' actionformats '${VCS_NAME_COLOR}%s%{${reset_color}%}' '${VCS_BRANCH_COLOR}%b%{${reset_color}%}:${VCS_ACTION_COLOR}%a%{${reset_color}%}' '%c' '%u'
fi


function vcs_super_info() {
    # カレントがgitレポジトリ下かどうか判定
    # zsh-git-prompt
    if [ "$ZSH_VCS_PROMPT_USING_PYTHON" = 'true' ] \
        && type git > /dev/null 2>&1 \
        && [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = "true" ]; then
        echo "(${VCS_NAME_COLOR_USING_PYTHON}git%{${reset_color}%})-[$(_git_status_using_python)]"
        return 0
    fi

    # zsh-git-promptが使用できない場合
    psvar=()
    LANG=en_US.UTF-8 vcs_info

    if [ "$vcs_info_msg_0_" = "git" ]; then
        echo "(${VCS_NAME_COLOR}$vcs_info_msg_0_%{${reset_color}%})-[$(_git_status)]"
    else
        echo "${VCS_NAME_COLOR}$vcs_info_msg_0_%{${reset_color}%}"
    fi
}


function _git_status() {
    local branch="$vcs_info_msg_1_"
    local staged="$vcs_info_msg_2_"
    local unstaged="$vcs_info_msg_3_"
    local untracked="${VCS_UNTRACKED_COLOR}${VCS_UNTRACKED_SIGIL}"
    local stashed="${VCS_STASHED_COLOR}${VCS_STASHED_SIGIL}"
    local conflicts="${VCS_CONFLICTS_COLOR}${VCS_CONFLICTS_SIGIL}"
    local ahead="${VCS_REMOTE_COLOR}${VCS_AHEAD_SIGIL}"
    local behind="${VCS_REMOTE_COLOR}${VCS_BEHIND_SIGIL}"
    local clean="${VCS_CLEAN_COLOR}${VCS_CLEAN_SIGIL}%{${reset_color}%}"

    local conflicts_count=0

    # staged
    local staged_files="$(git diff --staged --name-status)"
    if [ -n "$staged_files" ];then
        conflicts_count=$(echo "$staged_files" | sed '/^[^U]/d' | wc -l | sed 's/ //g')
        staged_count=$(echo "$staged_files" | wc -l | sed 's/ //g')
        staged_count=$(($staged_count - $conflicts_count))

        if [ -z "$staged" ];then
            # stagedな新規ファイルがvcs_infoで検出されない
            # (only Initial commit)
            staged="${VCS_STAGED_COLOR}${VCS_STAGED_SIGIL}"
        fi
        staged="$staged$staged_count%{${reset_color}%}"
    fi

    # conflicts
    if [ "$conflicts_count" -gt 0 ]; then
        conflicts="$conflicts$conflicts_count%{${reset_color}%}"
    else
        conflicts=""
    fi

    # unstaged
    local unstaged_files="$(git diff --name-status)"
    if [ -n "$unstaged_files" ]; then
        unstaged_count=$(echo "$unstaged_files" | sed '/^U/d' | wc -l | sed 's/ //g')
        unstaged="$unstaged$unstaged_count%{${reset_color}%}"
    fi

    # untracked
    untracked_files=$(git ls-files --others --exclude-standard)
    if [ -n "$untracked_files" ]; then
        untracked_count=$(echo "$untracked_files" | wc -l | sed 's/ //g')
        untracked="$untracked$untracked_count%{${reset_color}%}"
    else
        untracked=""
    fi

    # not pushed
    local remote="$(git status -sb | command grep -PZo '(?<= \[).*(?=])')"
    if [ -n "$remote" ];then
        local ahead_count="$(echo "$remote" | command grep -PZo '(?<=ahead )\d*')"
        if [ -n "$ahead_count" ];then
            ahead="$ahead$ahead_count%{${reset_color}%}"
        else
            ahead=""
        fi
        local behind_count="$(echo "$remote" | command grep -PZo '(?<=behind )\d*')"
        if [ -n "$behind_count" ];then
            behind="$behind$behind_count%{${reset_color}%}"
        else
            behind=""
        fi
    else
        ahead=""
        behind=""
    fi

    # stash
    local stash_list="$(git stash list)"
    if [ -n "$stash_list" ]; then
        stashed_count=$(echo "$stash_list" | wc -l | sed 's/ //g')
        stashed="$stashed$stashed_count%{${reset_color}%}"
    else
        stashed=""
    fi

    # result
    local git_status="${branch}${ahead}${behind}|${staged}${unstaged}${untracked}${conflicts}${stashed}"

    if [ -z "$staged" -a -z "$unstaged" -a -z "$untracked" -a -z "$conflicts" ]; then
        git_status="${git_status}${clean}"
    fi

    echo "$git_status%{${reset_color}%}"
}

function _git_status_using_python() {
    local cmd_gitstatus="${ZSH_VCS_PROMPT_DIR}/gitstatus-fast.py"

    if [ ! -f "$cmd_gitstatus" ]; then
        echo '[ zsh-vcs-prompt error: gitstatus-fast.py is not found ]'
        return 0
    fi

    GIT_STATUS=$(python "$cmd_gitstatus" 2>/dev/null)
    if [ -z "$GIT_STATUS" ];then
        return 0
    fi

    CURRENT_GIT_STATUS=("${(@f)GIT_STATUS}")
    GIT_BRANCH=$CURRENT_GIT_STATUS[1]
    GIT_REMOTE=$CURRENT_GIT_STATUS[2]
    GIT_STAGED=$CURRENT_GIT_STATUS[3]
    GIT_CONFLICTS=$CURRENT_GIT_STATUS[4]
    GIT_UNSTAGED=$CURRENT_GIT_STATUS[5]
    GIT_UNTRACKED=$CURRENT_GIT_STATUS[6]
    GIT_STASHED=$CURRENT_GIT_STATUS[7]
    GIT_CLEAN=$CURRENT_GIT_STATUS[8]


    local STATUS="($GIT_BRANCH"
    STATUS="$VCS_BRANCH_COLOR$GIT_BRANCH%{${reset_color}%}"
    if [ -n "$GIT_REMOTE" ]; then
        STATUS="$STATUS$VCS_REMOTE_COLOR$GIT_REMOTE%{${reset_color}%}"
    fi
    STATUS="$STATUS|"
    if [ "$GIT_STAGED" -ne "0" ]; then
        STATUS="$STATUS$VCS_STAGED_COLOR$VCS_STAGED_SIGIL$GIT_STAGED%{${reset_color}%}"
    fi
    if [ "$GIT_CONFLICTS" -ne "0" ]; then
        STATUS="$STATUS$VCS_CONFLICTS_COLOR$VCS_CONFLICTS_SIGIL$GIT_CONFLICTS%{${reset_color}%}"
    fi
    if [ "$GIT_UNSTAGED" -ne "0" ]; then
        STATUS="$STATUS$VCS_UNSTAGED_COLOR$VCS_UNSTAGED_SIGIL$GIT_UNSTAGED%{${reset_color}%}"
    fi
    if [ "$GIT_UNTRACKED" -ne "0" ]; then
        STATUS="$STATUS$VCS_UNTRACKED_COLOR$VCS_UNTRACKED_SIGIL$GIT_UNTRACKED%{${reset_color}%}"
    fi
    if [ "$GIT_STASHED" -ne "0" ]; then
        STATUS="$STATUS$VCS_STASHED_COLOR$VCS_STASHED_SIGIL$GIT_STASHED%{${reset_color}%}"
    fi
    if [ "$GIT_CLEAN" -eq "1" ]; then
        STATUS="$STATUS$VCS_CLEAN_COLOR$VCS_CLEAN_SIGIL%{${reset_color}%}"
    fi
    STATUS="$STATUS%{${reset_color}%}"
    echo "$STATUS"
}

# vim: ft=zsh
