# Solera: integra Homebrew en el PATH del usuario si está bootstrapeado.
# El bootstrap real lo hace el usuario:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Homebrew se instalará en ~/.linuxbrew o /home/linuxbrew/.linuxbrew según
# permisos. Cuando exista, este snippet lo activa.

if [ -d /home/linuxbrew/.linuxbrew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d "$HOME/.linuxbrew" ]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi
