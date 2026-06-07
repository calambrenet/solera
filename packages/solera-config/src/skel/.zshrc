# Powerlevel10k instant prompt. Debe ir al principio de .zshrc; cualquier
# código que requiera input (passwords, prompts y/n) tiene que ir por encima.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Tema: paquete oficial zsh-theme-powerlevel10k (NO clonar el repo en $HOME;
# en una distro inmutable el tema vive en /usr/share).
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# Config p10k personalizada (generada con `p10k configure`). Se incluye en
# /etc/skel/.p10k.zsh y se copia al home al crear el usuario.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Plugins: paquetes oficiales de Arch en /usr/share/zsh/plugins/.
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Completions: zsh-completions ship sus funciones bajo /usr/share/zsh/site-functions.
fpath=(/usr/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit

# History substring search con flechas arriba/abajo.
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# PATH del usuario.
export PATH="$HOME/.local/bin:$PATH"

# ---- Aliases -----------------------------------------------------------
# Listing
alias la='ls -a'
alias ll='ls -l'
alias lla='ls -la'
alias lt='ls -lhtr'                    # ordenados por fecha, más nuevos abajo
alias l.='ls -d .*'                    # solo ocultos

# Git (los 6 más usados a diario)
alias gs='git status'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'
alias gl='git log --oneline --graph --decorate --all'
alias gp='git pull'

# Solera
alias update='sudo arkdep update'
alias rollback='sudo arkdep deployments'  # lista deployments para elegir rollback
alias system-info='inxi -Fxz'

# Calidad de vida
alias please='sudo $(fc -ln -1)'       # repite último comando con sudo
alias reload='source ~/.zshrc'
alias path='echo -e ${PATH//:/\\n}'    # PATH una entrada por línea
alias myip='curl -s ifconfig.me'
