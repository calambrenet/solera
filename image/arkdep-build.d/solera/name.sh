# Genera el nombre de la imagen.
# Convención Solera: <variant>-<release>-build-<build_id>
# Ejemplo: solera-26-04-build-20260517-180000
#
# IMPORTANTE: el deployment_id NO puede contener puntos. arkdep parsea el
# nombre del archivo en cache vía `readarray -d . -t data_inter` (línea 985
# de arkdep) asumiendo el formato `<id>.tar.zst` con cero puntos en <id>.
# Si la release es "26.04", el split toma `solera-26` como id y arkdep no
# encuentra el archivo → cae a modo download. Por eso convertimos
# SOLERA_RELEASE ("26.04") a "26-04" para el nombre del archivo.
# El VERSION_ID legible (en /etc/os-release) sigue siendo "26.04".
#
# Vars de entorno consumidas:
#   SOLERA_RELEASE   release semestral (formato YY.MM)  default: 26.04
#   SOLERA_BUILD     identificador interno de build     default: timestamp
_release="${SOLERA_RELEASE:-26.04}"
_build="${SOLERA_BUILD:-$(date +%Y%m%d-%H%M%S)}"
echo "solera-${_release//./-}-build-${_build}"
