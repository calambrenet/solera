# Hardening de la imagen base

Decisiones de seguridad tomadas sobre la imagen base de Solera, con el
razonamiento detrás de cada una. Origen: auditoría manual del
2026-08-26 sobre `solera-26-04-build-20260824-093721`.

## Red

- **LLMNR desactivado** (`/etc/systemd/resolved.conf.d/10-solera-hardening.conf`,
  aportado por `solera-config`). LLMNR no tiene caso de uso legítimo real en
  Linux y es un vector conocido de envenenamiento de nombres en LAN
  (herramientas tipo Responder lo explotan de forma trivial).
- **mDNS (5353) se deja activo por defecto.** Es el mecanismo de
  descubrimiento de impresoras de red y Chromecast/AirPlay, un caso de uso
  real para el perfil de escritorio actual de Solera. No hay todavía un
  toggle "modo endurecido" que lo desactive — se revisará si Solera
  introduce un perfil corporativo/administrado explícito.
- **ufw activo con política por defecto `deny (incoming)`**
  (`/etc/default/ufw` vía `solera-config`, `ufw.service` habilitado por
  symlink en el mismo paquete). Sin cambios en esta tanda; pendiente de
  reverificación en un build real.

## Kernel (`/etc/sysctl.d/50-solera-hardening.conf`)

| sysctl | valor | por qué |
|---|---|---|
| `kernel.kptr_restrict` | 2 | oculta punteros del kernel; dificulta saltar KASLR desde un exploit local |
| `kernel.dmesg_restrict` | 1 | dmesg solo para CAP_SYSLOG |
| `kernel.kexec_load_disabled` | 1 | evita cargar un kernel arbitrario en caliente |
| `kernel.perf_event_paranoid` | 2 (no 3) | cierra la mayoría de eventos de CPU/kernel sin privilegios pero deja `perf` usable sin sudo — Solera también es plataforma de desarrollo |
| `net.ipv4.conf.all.rp_filter` | 1 | anti-spoofing |
| `net.ipv4/6.conf.all.accept_redirects`, `send_redirects` | 0 | no confiar en ICMP redirects no solicitados |

Deliberadamente **sin tocar**: `kernel.unprivileged_userns_clone` (se queda
en `1`, en `99-solera.conf`) — es lo que hace posible Podman rootless y el
sandbox de Flatpak, dos pilares del modelo de seguridad de Solera.

## Binarios SUID

- **`/usr/bin/suexec` (apache) eliminado** quitando `gnome-user-share` de
  `solera-meta`: es la única razón por la que `apache` entraba en la
  imagen (dependencia dura, confirmado con `pacman -Sii gnome-user-share`).
  "Personal File Sharing" por WebDAV es una función GNOME poco usada hoy.
- **`/usr/bin/ksu` (krb5) pierde el bit SUID** en
  `image/arkdep-build.d/solera/extensions/post_install.sh`. `krb5` en sí es
  una dependencia transitiva ineliminable (la arrastran `curl`, `openssh`,
  `gnome-online-accounts`, `cifs-utils`, `nfs-utils`...), pero `ksu` no
  tiene caso de uso en un escritorio sin infraestructura Kerberos
  desplegada.

## Podman vs. Docker

`/usr/bin/docker` en la imagen **no es el paquete `docker` real**: lo
aporta `podman-docker`, un shim CLI que reescribe invocaciones `docker` a
`podman`. No hay demonio, no hay `docker.service`, y por eso el grupo
`docker` nunca ha existido en la imagen. `image/.../post_install.sh` ahora
aborta el build si ese grupo apareciera — es la comprobación estructural
que garantiza que "Podman en vez de Docker" se mantiene cierto, en vez de
confiar solo en que nadie añada el paquete `docker` real.

## Firma de paquetes y de imágenes

- El repo pacman `[solera]` exige `Required DatabaseOptional` en
  producción (antes solo `Required`, que además exigía firmar la base de
  datos del repo — cosa que no hacemos con `repo-add`). `image/build.sh`
  aborta el build si detecta `TrustAll` en un `pacman.conf` de producción.
- La verificación de firma de las imágenes de `arkdep` (`solera update` /
  `arkdep deploy` por red) ya era obligatoria
  (`dist_gpg_signature_check=2`, parcheado en `packages/arkdep/PKGBUILD`).
  Solo se relaja durante el deploy inicial desde el medio de instalación
  de confianza (`20-arkdep-deploy.sh`), y se restaura a obligatorio
  inmediatamente después.

## Manejadores de esquema de URL (`x-scheme-handler`)

Pendiente de rellenar tras el próximo build. Procedimiento sobre una
imagen/deployment real (no se puede hacer por grep estático del repo,
estos `.desktop` los aportan paquetes ya instalados):

```bash
grep -rl 'x-scheme-handler' /usr/share/applications/ | while read -r f; do
    printf '== %s (%s) ==\n' "$f" "$(pacman -Qo "$f" 2>/dev/null | awk '{print $NF}')"
    grep -E '^Exec=|^MimeType=' "$f"
done
```

Para cada uno: comprobar si `Exec=` pasa `%u`/`%U` a un shell, un
intérprete, o un fichero de configuración que después se evalúa (el
vector del RCE de dos clics publicado contra Omarchy). Los que no se
justifiquen, se quitan de la imagen base.

| `.desktop` | paquete | esquema(s) | veredicto |
|---|---|---|---|
| _(pendiente)_ | | | |
