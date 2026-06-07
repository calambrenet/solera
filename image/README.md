# `image/` — construcción de la imagen del sistema

La receta de `arkdep-build` para Solera vive en `arkdep-build.d/solera/`. Su contrato (heredado de upstream `arkdep`):

| Archivo | Rol |
|---|---|
| `type` | Contiene `archlinux`: indica a `arkdep-build` que use `pacstrap`. |
| `name.sh` | Genera el nombre del artefacto. Convención Solera: `solera-<release>-build-<build_id>`. |
| `bootstrap.list` | Paquetes que `pacstrap` instala en una subvolume vacía. Mínimo arrancable + `solera-keyring`. |
| `package.list` | Paquetes que `pacman -S` instala dentro del chroot. Solo `solera-meta` (sus deps traen el resto). |
| `pacman.conf` | Generado por `build.sh` desde `pacman.conf.template`. Apunta a un snapshot del Arch Linux Archive **y** al repo de Solera. |
| `overlay/post_bootstrap/` | Archivos copiados al rootfs antes de la segunda fase. Lleva `nsswitch.conf` (extrausers), `dracut.conf.d/solera.conf`, `dconf/profile/user`. |
| `overlay/post_install/` | Archivos copiados después de la segunda fase. Placeholder por ahora; lo real lo aporta `solera-config`. |
| `extensions/post_install.sh` | Hook tras la segunda fase: `dconf update`, dracut tweaks. |
| `update.sh` | Empaquetado dentro de la imagen; lo invoca `arkdep` durante despliegues. |

## Construcción local

Requisitos en el host:

- `arkdep`, `arch-install-scripts` (`pacstrap`), `btrfs-progs`, `dracut`.
- Repositorio pacman accesible localmente o por HTTP/S3 con los paquetes `solera-meta`, `solera-config`, `solera-keyring`, `arkdep` y `os-installer-config-solera` ya publicados.
- Subir el llavero al pacman del host: `sudo pacman-key --add /path/solera.gpg && sudo pacman-key --lsign-key <FPR>`.

Ejemplo (con un repo local en `/srv/solera-localrepo`):

```bash
SOLERA_ALA_DATE=2026/04/30 \
SOLERA_RELEASE=26.04 \
SOLERA_BUILD=$(date +%Y%m%d-%H%M%S) \
SOLERA_REPO_URL='file:///srv/solera-localrepo' \
sudo -E ./image/build.sh
```

Resultado en `./target/`:

```
solera-26.04-build-20260517-180000.tar.zst          # imagen empaquetada
solera-26.04-build-20260517-180000.pkgs             # manifiesto de paquetes
solera-26.04-build-20260517-180000/                 # subvolúmenes raw
    *-rootfs.img
    *-etc.img
    *-var.img
    *-update.sh
```

La línea `id:compress:sha256sum` que `arkdep-build` imprime al final es la **database entry** que el servidor pacman/CDN sirve para que `arkdep deploy` sepa qué imagen instalar.

## Variables admitidas por `build.sh`

| Variable | Default | Descripción |
|---|---|---|
| `SOLERA_ALA_DATE` | último día del mes anterior | Fecha `YYYY/MM/DD` del Arch Linux Archive. La imagen se construye solo contra ese snapshot. |
| `SOLERA_RELEASE` | `26.04` | Release semestral (`YY.MM`). |
| `SOLERA_BUILD` | timestamp | Identificador interno de build (separado de `RELEASE`). |
| `SOLERA_REPO_URL` | (obligatorio) | URL base del repo pacman propio de Solera. Ej.: `file:///srv/solera-localrepo` o `https://repo.soleralinux.org/stable/repo`. |
| `SOLERA_OUT` | `./target` | Dónde escribir los artefactos. |

## Reproducibilidad

Reconstruir contra el **mismo** `SOLERA_ALA_DATE` y la misma versión de `solera-meta`/`solera-config` debe producir un artefacto equivalente (mismo contenido). Cambios en el `SOLERA_BUILD` no son nuevos contenidos; son solo etiquetas.

## Publicación

El artefacto se firma con la clave de Solera y se sube al bucket R2
bajo `images/solera/`, junto a una entrada en el archivo `database` que
`arkdep deploy` lee para saber qué imagen instalar.
