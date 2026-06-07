# update.sh — script empaquetado dentro de la imagen y ejecutado por
# `arkdep` durante el despliegue. Sitio reservado para migraciones entre
# versiones de Solera (mover archivos a nueva ubicación, etc.).
#
# Plantilla mínima. Pre-arkdep "EFI var drop": si existe la entrada vieja del
# loader, la renombra para conservar histórico.
if [[ -f $arkdep_boot/loader/entries/${data[0]}.conf ]]; then
    mv $arkdep_boot/loader/entries/${data[0]}.conf \
       $arkdep_boot/loader/entries/$(date +%Y%m%d-%H%M%S)-${data[0]}+3.conf
    bootctl set-default ''
fi
