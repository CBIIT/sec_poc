# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ls='ls --color -lah'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

#export EDITOR=/usr/bin/vim

HISTCONTROL=ignoreboth
shopt -s histappend
shopt -s cmdhist
HISTSIZE=1000000
HISTFILESIZE=1000000

export PROMPT_COMMAND=__prompt_command  # Func to gen PS1 after CMDs

function __prompt_command() {
    local EXIT="$?"             # This needs to be first

    local RCol='\033[0m'
    local Red='\033[0;31m'

    history -a

    if [ $EXIT != 0 ]
    then
        PS1="\[${Red}\][ \w ]\[${RCol}\]"
    else
        PS1="[ \w ]"
    fi
    uid=`id -u`
    if [ $uid == 0 ]
    then
        PS1+="# "
    else
        PS1+="$ "
    fi
}


# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

#if [ -f ~/.bash_aliases ]; then
#    . ~/.bash_aliases
#fi

cd /opt/R/CTRP/sec_poc
