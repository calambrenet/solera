# Imagen "smoketest" de Solera: mínimo arrancable sin GNOME, sin solera-meta.
# Existe solo para validar que el flujo de instalación offline (bundle en ISO
# + arkdep deploy cache) funciona end-to-end. Sustituir por la imagen real
# en cuanto la receta `solera/` pueda construirse (bloqueada por AUR mirrors).
echo "solera-smoketest-${SOLERA_BUILD:-$(date +%Y%m%d-%H%M%S)}"
