#
# ~/.bashrc (default Solera skeleton)
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

# Aliases sensatos por defecto
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -lah'

# Aviso amistoso: en Solera, instalar paquetes en el host es la excepción
# (uses Flatpak, Distrobox o Homebrew).
solera-help() {
    cat <<-EOF
	Solera Linux — atajos rápidos:

	  flatpak install flathub <app-id>     Instala una app de escritorio
	  distrobox-create --name <env>        Crea un entorno de desarrollo
	  brew install <utilidad>              Instala una CLI en \$HOME
	  arkdep update                        Trae la última imagen Solera
	  arkdep layer <pkg>                   (Avanzado) capa un paquete nativo

	Documentación: https://github.com/calambrenet/solera
	EOF
}
