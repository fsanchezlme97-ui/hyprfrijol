#!/usr/bin/env bash
# hyprfrijol — instalador para cualquier distro, también sin escritorio (instalación mínima o servidor)
#
#   ./install.sh                  dependencias + arranque mínimo del sistema + scripts + sesión «Hyprland (HyprFrijol)»
#   ./install.sh --dry-run        enseña los comandos exactos sin ejecutar nada
#   ./install.sh --yes            sin preguntas: acepta lo recomendado (los opcionales, solo con --full)
#   ./install.sh --full           también los opcionales (VMs, contenedores, VPN, escáner, Bluetooth, Valent, fondos
#                                 animados…); después, uno a uno: hf-deps install <función> (lista: hf-deps list)
#   ./install.sh --no-deps        sin paquetes ni repositorios extra
#   ./install.sh --no-system      sin tocar servicios ni grupos (NetworkManager, PipeWire, logind, grupo video…)
#   ./install.sh --no-session     sin la entrada en el gestor de inicio
#   ./install.sh --uninstall      quita enlaces, lanzadores y la entrada de sesión (tus ajustes se quedan)
#   ./install.sh --uninstall --purge   además borra ajustes, estado y caché de hyprfrijol
#   ./install.sh --greeter        (opcional) login visual con greetd; guarda el gestor actual para volver
#   ./install.sh --greeter-off    vuelve al gestor de inicio que había antes
#   ./install.sh --greeter-sync   copia tu tema y tu fondo al login (scripts/hf-greeter-sync)
#   ./install.sh --migrate        pasa una instalación de hypr-liquid (nombre anterior) a hyprfrijol
#   ./install.sh --apps=serie,productividad   apps por nivel (install/apps.json, scripts/hf-apps): serie (por defecto),
#                                 productividad, destacada, creativa, experimental, all; --apps=none o --no-apps: ninguna
#
# Pruebas: HF_DISTRO=<id> [HF_DISTRO_VERSION=<versión o nombre>] simula otra distro (úsalo con --dry-run);
#          HF_INIT=systemd|runit|openrc fuerza el sistema de arranque; HF_NO_COLORS=1 no genera los colores iniciales. Ids: arch cachyos endeavouros manjaro garuda
#          fedora rocky almalinux opensuse-tumbleweed opensuse-leap debian ubuntu pop linuxmint void gentoo nixos.
#
# Se puede repetir sin miedo: solo hace lo que falta. No toca ~/.config/hypr, ~/.config/quickshell ni
# ~/.config/matugen: hyprfrijol se ejecuta desde esta carpeta como una sesión aparte.
set -euo pipefail

DRY=0 YES=0 FULL=0 DEPS=1 SYSTEM=1 SESSION=1 UNINSTALL=0 PURGE=0 GREETER="" MIGRATE=0
APPS=""   # niveles de install/apps.json (--apps=…); vacío = preguntar (o «serie» con --yes/--dry-run)
for a in "$@"; do
  case "$a" in
    --dry-run)      DRY=1 ;;
    -y|--yes)       YES=1 ;;
    --full)         FULL=1 ;;
    --no-deps)      DEPS=0 ;;
    --no-system)    SYSTEM=0 ;;
    --no-session)   SESSION=0 ;;
    --uninstall)    UNINSTALL=1 ;;
    --purge)        PURGE=1 ;;
    --greeter)      GREETER=on ;;
    --greeter-off)  GREETER=off ;;
    --greeter-sync) GREETER=sync ;;
    --apps=*)       APPS="${a#--apps=}" ;;
    --no-apps)      APPS=none ;;
    --migrate)      MIGRATE=1 ;;
    -h|--help)      sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opción desconocida: $a (usa --help)" >&2; exit 1 ;;
  esac
done
[ "$PURGE" = 1 ] && [ "$UNINSTALL" = 0 ] && { echo "--purge va con --uninstall" >&2; exit 1; }

# La carpeta del repo, esté donde esté clonado (~/hyprfrijol, ~/.local/src/hyprfrijol…), aunque se llame por un enlace
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PKG_TABLE="$HERE/install/packages.tsv"
BIN="$HOME/.local/bin"
USERCFG="$HOME/.config/hyprfrijol"
STATE="$HOME/.local/state/hyprfrijol"
SESSION_FILE=/usr/share/wayland-sessions/hyprfrijol.desktop
SAFE_SESSION_FILE=/usr/share/wayland-sessions/hyprfrijol-seguro.desktop   # «HyprFrijol (modo seguro)» (hf-safe)
MIN_HYPR=0.57
MIN_QS=0.3

# ---------- Salida ----------
if [ -t 1 ]; then C1=$'\033[1;36m' C2=$'\033[1;33m' C3=$'\033[1;31m' C4=$'\033[1m' C0=$'\033[0m'; else C1="" C2="" C3="" C4="" C0=""; fi
say()  { printf '%s▸%s %s\n' "$C1" "$C0" "$*"; }
warn() { printf '%s!%s %s\n' "$C2" "$C0" "$*"; }
err()  { printf '%s✗%s %s\n' "$C3" "$C0" "$*" >&2; }
hdr()  { printf '\n%s── %s%s\n' "$C4" "$*" "$C0"; }
note() { printf '    %s\n' "$@"; }

DONE=() SKIPPED=() TODO=()
done_() { DONE+=("$*"); }
skip_() { SKIPPED+=("$*"); }
todo_() { TODO+=("$*"); }

# run: ejecuta, o con --dry-run solo lo enseña (citado para poder copiarlo)
run() {
  if [ "$DRY" = 1 ]; then printf '  [dry-run]'; printf ' %q' "$@"; echo; else "$@"; fi
}
# root: lo mismo con sudo (o doas); como root, sin prefijo
SUDO=()
if [ "$(id -u)" != 0 ]; then
  if command -v sudo >/dev/null; then SUDO=(sudo); elif command -v doas >/dev/null; then SUDO=(doas); fi
fi
root() {
  if [ "$DRY" = 1 ]; then run "${SUDO[@]:-sudo}" "$@"; return; fi
  if [ "$(id -u)" != 0 ] && [ ${#SUDO[@]} -eq 0 ]; then err "Hace falta sudo o doas para: $*"; return 1; fi
  run ${SUDO[@]+"${SUDO[@]}"} "$@"
}
# root_write FICHERO MODO  (contenido por la entrada estándar)
root_write() {
  local f="$1" mode="$2" tmp
  if [ "$DRY" = 1 ]; then
    printf '  [dry-run] %s install -Dm%s /dev/stdin %q  <<EOF\n' "${SUDO[*]:-sudo}" "$mode" "$f"
    sed 's/^/              /'; echo '              EOF'; return
  fi
  tmp="$(mktemp)"; cat > "$tmp"
  root install -Dm"$mode" "$tmp" "$f"; rm -f "$tmp"
}
# ask "pregunta" s|n → 0 = sí. Con --yes o --dry-run usa la respuesta por defecto. Lee de /dev/tty (curl … | bash).
ask() {
  local q="$1" def="$2" ans="" hint="[S/n]"; [ "$def" = n ] && hint="[s/N]"
  if [ "$YES" = 1 ] || [ "$DRY" = 1 ]; then
    [ "$DRY" = 1 ] && printf '  [dry-run] pregunta: %s %s → %s\n' "$q" "$hint" "$([ "$def" = s ] && echo sí || echo no)"
    [ "$def" = s ]; return
  fi
  printf '%s?%s %s %s ' "$C1" "$C0" "$q" "$hint"
  { read -r ans </dev/tty; } 2>/dev/null || { echo; ans=""; }
  case "${ans:-$def}" in [sSyY]*) return 0 ;; *) return 1 ;; esac
}
have() { command -v "$1" >/dev/null 2>&1; }
# version_ge A B → A ≥ B
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

if [ "$(id -u)" = 0 ] && [ "$DRY" = 0 ] && [ -z "${HF_ALLOW_ROOT:-}" ]; then
  err "Ejecútalo con tu usuario, no como root: instala en tu \$HOME y pide sudo solo para lo del sistema."
  exit 1
fi

# ---------- Distro ----------
# Detección (compartida con scripts/hf-apps): load_os_release, family_of
. "$HERE/install/distro.sh"
FAMILY=unknown
detect_distro() {
  load_os_release
  local w
  if ! FAMILY="$(family_of "$OS_ID")"; then
    FAMILY=unknown
    for w in $OS_LIKE; do FAMILY="$(family_of "$w")" && break || FAMILY=unknown; done
  fi
  # Ubuntu y derivadas (Mint, Pop!_OS…): la base que cuenta es la de Ubuntu
  UB=""
  if [ "$FAMILY" = ubuntu ]; then
    UB="$OS_UCODENAME"
    if [ -z "$UB" ] && [ "$OS_ID" = ubuntu ]; then
      case "$OS_VER" in 24.04) UB=noble ;; 24.10) UB=oracular ;; 25.04) UB=plucky ;; 25.10) UB=questing ;;
                        26.04) UB=resolute ;; 26.10) UB=stonking ;; *) UB="$OS_CODENAME" ;; esac
    fi
  fi
  DEB="$OS_CODENAME"   # Debian: trixie (13), forky (14, testing), sid
  if [ "$FAMILY" = debian ] && [ -z "$DEB" ]; then case "$OS_VER" in 12) DEB=bookworm ;; 13) DEB=trixie ;; 14) DEB=forky ;; esac; fi
  case "$FAMILY" in
    arch) PM=pacman COL=3 ;; fedora|rhel) PM=dnf COL=4 ;; suse|suse-leap) PM=zypper COL=5 ;;
    debian|ubuntu) PM=apt-get COL=6 ;; void) PM=xbps-install COL=7 ;; *) PM="" COL="" ;;
  esac
  # Sistema de arranque
  if [ -n "${HF_INIT:-}" ]; then INIT="$HF_INIT"
  elif [ "$SIMULATED" = 1 ]; then case "$FAMILY" in void) INIT=runit ;; gentoo) INIT=openrc ;; *) INIT=systemd ;; esac
       [ "$OS_ID" = artix ] && INIT=openrc
  elif [ -d /run/systemd/system ]; then INIT=systemd
  elif [ -d /etc/runit ] || [ -d /var/service ]; then INIT=runit
  elif have rc-service; then INIT=openrc
  else INIT=otro; fi
  # Con una distro simulada no se consulta el sistema real (gestor de paquetes, servicios…)
  PROBE=1; [ "$SIMULATED" = 1 ] && PROBE=0
  [ "$PROBE" = 1 ] && [ -n "$PM" ] && ! have "$PM" && PROBE=0
  return 0
}

# ---------- Servicios (systemd / runit) ----------
svc_active() {   # ¿está en marcha?
  [ "$PROBE" = 1 ] || return 1
  case "$INIT" in
    systemd) systemctl is-active --quiet "$1" 2>/dev/null ;;
    runit)   [ -e "/var/service/$1" ] && sv status "$1" 2>/dev/null | grep -q '^run' ;;
    *) return 1 ;;
  esac
}
svc_enabled() {
  [ "$PROBE" = 1 ] || return 1
  case "$INIT" in
    systemd) systemctl is-enabled --quiet "$1" 2>/dev/null ;;
    runit)   [ -e "/var/service/$1" ] ;;
    *) return 1 ;;
  esac
}
svc_enable() {   # svc_enable NOMBRE [--now]
  case "$INIT" in
    systemd) if [ "${2:-}" = --now ]; then root systemctl enable --now "$1"; else root systemctl enable "$1"; fi ;;
    runit)   if [ "$DRY" = 1 ] || [ -d "/etc/sv/$1" ]; then root ln -sfn "/etc/sv/$1" "/var/service/$1"; else warn "No existe /etc/sv/$1"; return 1; fi ;;
    openrc)  root rc-update add "$1" default ;;
    *) warn "Activa a mano el servicio $1 en tu sistema de arranque"; return 1 ;;
  esac
}
svc_disable() {
  case "$INIT" in
    systemd) root systemctl disable "$1" ;;
    runit)   root rm -f "/var/service/$1" ;;
    openrc)  root rc-update del "$1" default ;;
    *) warn "Desactiva a mano el servicio $1"; return 1 ;;
  esac
}
current_dm() {
  [ "$PROBE" = 1 ] || { echo ""; return; }
  local d
  case "$INIT" in
    systemd) systemctl show -p Id --value display-manager.service 2>/dev/null | sed 's/\.service$//' ;;
    runit)   for d in gdm sddm lightdm lxdm ly emptty slim greetd plasmalogin; do [ -e "/var/service/$d" ] && { echo "$d"; return; }; done; echo "" ;;
    *) echo "" ;;
  esac
}

# ---------- Fuentes de Hyprland y Quickshell por distro ----------
# Comprobado el 2026-11-07 (repology.org, COPR, OBS, Launchpad, wiki.hypr.land, quickshell.org):
#   Arch/CachyOS/EndeavourOS/Garuda: repos oficiales (hyprland 0.57.1, quickshell 0.3.2, matugen 4.2.0); mpvpaper en AUR.
#     Manjaro estable va por detrás (0.56.2): rama testing/unstable.
#   Fedora 44/45: COPR lionheartp/Hyprland (hyprland 0.57.1, quickshell 0.3.2, matugen, mpvpaper, hyprlock…).
#     solopasha/hyprland está parado en 0.49. Alternativa para Quickshell: COPR errornointernet/quickshell (también EPEL 10).
#   openSUSE Tumbleweed/Slowroll: hyprland 0.57.0 oficial; quickshell y matugen en OBS home:AvengeMedia:danklinux. Leap: sin Hyprland.
#   Debian 14 (forky/testing) y sid: hyprland 0.57.0 y quickshell 0.3.2 oficiales; matugen con cargo. Trixie-backports: 0.55 (no vale).
#   Ubuntu 24.04/26.04 (y Mint 22, Pop!_OS 24.04): ppa:cppiber/hyprland (0.57.1). Quickshell y matugen: ppa:avengemedia/danklinux
#     (26.04 y 26.10; 24.04 no → compilar Quickshell). Ubuntu 26.10 trae 0.56.2 y el PPA de Hyprland aún no lo cubre.
#   Void: quickshell y matugen oficiales; Hyprland no (el repo externo hyprland-void se quedó en 0.49).
COPR_HYPR=lionheartp/Hyprland
COPR_QS=errornointernet/quickshell
OBS_DANK="https://download.opensuse.org/repositories/home:AvengeMedia:danklinux"
PPA_HYPR=ppa:cppiber/hyprland
PPA_QS=ppa:avengemedia/danklinux
HYPR_SRC="" QS_SRC="" HYPR_MANUAL=0 QS_MANUAL=0 EXTRA_PKGS=() AURH=""

hypr_help() {   # cómo conseguir Hyprland ≥ 0.57 en esta distro
  case "$FAMILY" in
    arch)
      if [ "$OS_ID" = manjaro ]; then
        note "Manjaro estable va por detrás. Pasa a la rama testing y actualiza:" \
             "  sudo pacman-mirrors --api --set-branch testing && sudo pacman -Syu hyprland"
      else note "sudo pacman -Syu hyprland"; fi ;;
    fedora)
      note "Necesitas Fedora 44 o posterior y el COPR $COPR_HYPR:" \
           "  sudo dnf install 'dnf-command(copr)' && sudo dnf copr enable $COPR_HYPR && sudo dnf install hyprland"
      [ -n "$OS_VER" ] && [ "${OS_VER%%.*}" -lt 44 ] 2>/dev/null && note "Tienes Fedora $OS_VER: actualiza con «sudo dnf system-upgrade»." ;;
    rhel)
      note "No hay Hyprland ≥ 0.57 empaquetado para RHEL/Rocky/Alma. Opciones:" \
           "  · compilarlo: https://wiki.hypr.land/Getting-Started/Installation/ (sección «Manual build»; gcc ≥ 16 o clang ≥ 19)" \
           "  · o usar Fedora 44+, que sí tiene COPR" ;;
    suse)
      note "sudo zypper refresh && sudo zypper dup && sudo zypper install hyprland" ;;
    suse-leap)
      note "Leap no tiene Hyprland (sus bibliotecas y compilador son demasiado antiguos)." \
           "  Pasa a openSUSE Tumbleweed o Slowroll, o compílalo: https://wiki.hypr.land/Getting-Started/Installation/" ;;
    debian)
      note "Hyprland ≥ 0.57 está en Debian 14 (forky/testing) y sid: sudo apt-get update && sudo apt-get install hyprland"
      case "$DEB" in
        trixie)   note "Debian 13: trixie-backports trae 0.55, que no basta. Pasa a testing o compílalo (wiki.hypr.land, «Manual build»)." ;;
        bookworm) note "Debian 12 es demasiado antiguo: actualiza a testing (forky)." ;;
      esac ;;
    ubuntu)
      case "$UB" in
        noble|resolute) note "PPA (no oficial) con Hyprland actual:" \
                             "  sudo add-apt-repository $PPA_HYPR && sudo apt-get update && sudo apt-get install hyprland" ;;
        stonking) note "Ubuntu 26.10 trae Hyprland 0.56.2 y $PPA_HYPR aún no publica para 26.10." \
                       "  Usa Ubuntu 26.04 LTS con el PPA, espera a 27.04, o compílalo (wiki.hypr.land, «Manual build»)." ;;
        *) note "Usa Ubuntu 24.04 o 26.04 con $PPA_HYPR, o compílalo (wiki.hypr.land, «Manual build»)." ;;
      esac ;;
    void)
      note "Void no empaqueta Hyprland y el repositorio externo hyprland-void se quedó en 0.49." \
           "  Compílalo (https://wiki.hypr.land/Getting-Started/Installation/, «Manual build»: hyprutils, hyprlang," \
           "  hyprcursor, hyprgraphics, aquamarine, hyprwire, glaze y luego hyprland, hyprlock, hypridle," \
           "  xdg-desktop-portal-hyprland) o usa el gestor de paquetes Nix: nix profile install nixpkgs#hyprland" ;;
    gentoo)
      note "sudo eselect repository enable hyproverlay && sudo emaint sync -r hyproverlay" \
           "sudo emerge --ask gui-wm/hyprland gui-apps/hyprlock gui-apps/hypridle gui-libs/xdg-desktop-portal-hyprland" ;;
    nixos)
      note "En configuration.nix:  programs.hyprland.enable = true;  (nixos-unstable trae 0.57)" ;;
    *)
      note "Instala Hyprland ≥ 0.57 con tu gestor de paquetes o compílalo: https://wiki.hypr.land/Getting-Started/Installation/" ;;
  esac
  return 0
}

setup_sources() {
  case "$FAMILY" in
    arch)
      HYPR_SRC="repos oficiales de Arch" QS_SRC="repos oficiales de Arch"
      [ "$OS_ID" = manjaro ] && HYPR_SRC="repos de Manjaro (la rama estable puede ir por detrás)"
      have paru && AURH=paru
      [ -z "$AURH" ] && have yay && AURH=yay
      [ "$SIMULATED" = 1 ] && AURH="${HF_AUR_HELPER:-}" ;;
    fedora)
      if [ -n "$OS_VER" ] && [ "${OS_VER%%.*}" -lt 44 ] 2>/dev/null; then
        warn "Fedora $OS_VER: el COPR $COPR_HYPR solo publica para Fedora 44, 45 y rawhide."
        HYPR_MANUAL=1 HYPR_SRC="(sin fuente: actualiza a Fedora 44+)"
        QS_SRC="COPR $COPR_QS"
        if ask "¿Activar el COPR $COPR_QS (Quickshell)?" s; then
          root dnf install -y 'dnf-command(copr)'; root dnf copr enable -y "$COPR_QS"; done_ "COPR $COPR_QS"
        fi
        return
      fi
      HYPR_SRC="COPR $COPR_HYPR" QS_SRC="COPR $COPR_HYPR"
      say "Hyprland ≥ $MIN_HYPR y Quickshell vienen del COPR $COPR_HYPR (comunitario, no oficial)."
      if ask "¿Activar el COPR $COPR_HYPR?" s; then
        root dnf install -y 'dnf-command(copr)'
        root dnf copr enable -y "$COPR_HYPR"; done_ "COPR $COPR_HYPR"
      else HYPR_MANUAL=1 QS_MANUAL=1; skip_ "COPR $COPR_HYPR (rechazado)"; fi ;;
    rhel)
      warn "RHEL y derivadas: Quickshell sí (EPEL 10 + COPR $COPR_QS), Hyprland ≥ $MIN_HYPR no está empaquetado."
      HYPR_MANUAL=1 HYPR_SRC="(sin paquete: compilar)" QS_SRC="COPR $COPR_QS (EPEL 10)"
      if ask "¿Activar EPEL y el COPR $COPR_QS?" s; then
        root dnf install -y epel-release || warn "En RHEL: sudo subscription-manager repos --enable codeready-builder-for-rhel-10-\$(arch)-rpms && sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm"
        root dnf install -y 'dnf-command(copr)'
        root dnf copr enable -y "$COPR_QS"; done_ "EPEL + COPR $COPR_QS"
      fi ;;
    suse|suse-leap)
      local sub=openSUSE_Tumbleweed
      if [ "$FAMILY" = suse-leap ]; then
        sub="${OS_VER:-16.0}"
        warn "openSUSE Leap no tiene Hyprland ≥ $MIN_HYPR: se instala el resto (Quickshell desde OBS)."
        HYPR_MANUAL=1 HYPR_SRC="(sin paquete en Leap)"
      else HYPR_SRC="repos oficiales de Tumbleweed"; fi
      QS_SRC="OBS home:AvengeMedia:danklinux"
      if [ "$PROBE" = 1 ] && zypper -q lr 2>/dev/null | grep -q 'AvengeMedia'; then
        say "Repositorio OBS home:AvengeMedia:danklinux ya añadido."
      elif ask "¿Añadir el repositorio OBS home:AvengeMedia:danklinux (Quickshell y matugen; comunitario)?" s; then
        root zypper --non-interactive addrepo --refresh "$OBS_DANK/$sub/home:AvengeMedia:danklinux.repo"
        root zypper --non-interactive --gpg-auto-import-keys refresh; done_ "OBS home:AvengeMedia:danklinux"
      else QS_MANUAL=1; skip_ "OBS home:AvengeMedia:danklinux (rechazado)"; fi ;;
    debian)
      case "$DEB" in
        forky|sid|"") HYPR_SRC="repos oficiales de Debian" QS_SRC="repos oficiales de Debian" ;;
        trixie) HYPR_MANUAL=1 HYPR_SRC="(trixie-backports tiene 0.55: no basta)"
                QS_SRC="trixie-backports (0.3.0)"
                warn "Debian 13: Hyprland ≥ $MIN_HYPR no está; se instala el resto."
                note "Quickshell: activa trixie-backports y luego: sudo apt-get install -t trixie-backports quickshell" ;;
        *) HYPR_MANUAL=1 QS_MANUAL=1 HYPR_SRC="(demasiado antiguo)" QS_SRC="(demasiado antiguo)"
           warn "Debian ${DEB:-$OS_VER}: demasiado antiguo para Hyprland ≥ $MIN_HYPR." ;;
      esac
      [ "$PROBE" = 1 ] && [ "$DRY" = 0 ] && { root apt-get update || true; }
      [ "$DRY" = 1 ] && root apt-get update ;;
    ubuntu)
      local ppas=()
      case "$UB" in
        resolute) ppas=("$PPA_HYPR" "$PPA_QS"); HYPR_SRC="$PPA_HYPR" QS_SRC="$PPA_QS"; EXTRA_PKGS+=(matugen) ;;
        noble)    ppas=("$PPA_HYPR"); HYPR_SRC="$PPA_HYPR"; QS_MANUAL=1; QS_SRC="(compilar: no hay paquete para 24.04)" ;;
        stonking) ppas=("$PPA_QS"); HYPR_MANUAL=1; HYPR_SRC="(26.10 trae 0.56.2: no basta)"; QS_SRC="$PPA_QS"; EXTRA_PKGS+=(matugen) ;;
        *) HYPR_MANUAL=1 QS_MANUAL=1 HYPR_SRC="(sin fuente conocida para ${UB:-esta versión})" QS_SRC="(compilar)"
           warn "Ubuntu ${UB:-$OS_VER}: no conozco una fuente de Hyprland ≥ $MIN_HYPR; se instala el resto." ;;
      esac
      if [ ${#ppas[@]} -gt 0 ]; then
        say "Hyprland/Quickshell actuales en Ubuntu vienen de PPAs comunitarios: ${ppas[*]}"
        if ask "¿Añadir ${ppas[*]}?" s; then
          have add-apt-repository || [ "$PROBE" = 0 ] || root apt-get install -y software-properties-common
          [ "$PROBE" = 0 ] && root apt-get install -y software-properties-common
          local p
          for p in "${ppas[@]}"; do
            if [ "$PROBE" = 1 ] && grep -rqs "${p#ppa:}" /etc/apt/sources.list.d/ 2>/dev/null; then say "$p ya está añadido."
            else root add-apt-repository -y "$p"; fi
            done_ "$p"
          done
        else
          HYPR_MANUAL=1 QS_MANUAL=1 EXTRA_PKGS=(); skip_ "PPAs ${ppas[*]} (rechazados)"
        fi
      fi
      [ "$DRY" = 1 ] && root apt-get update
      [ "$DRY" = 0 ] && [ "$PROBE" = 1 ] && { root apt-get update || true; } ;;
    void)
      HYPR_MANUAL=1 HYPR_SRC="(Void no lo empaqueta: compilar)" QS_SRC="repos oficiales de Void"
      warn "Void no empaqueta Hyprland, hyprlock, hypridle ni xdg-desktop-portal-hyprland: se instala el resto."
      if [ "$DRY" = 1 ] || [ "$PROBE" = 1 ]; then root xbps-install -S; fi ;;
  esac
  return 0
}

# ---------- Paquetes ----------
PKGS=() AURPKGS=() NOPKG=() OPTIONAL_IDS=() WANT_OPTIONAL=0 WANT_GREETD=0
read_table() {   # read_table NIVEL… → imprime «id<TAB>paquetes<TAB>descripción<TAB>nivel» de esta familia
  awk -F'\t' -v col="$COL" -v levels=" $* " '
    /^#/ || NF < 8 { next }
    index(levels, " " $2 " ") { print $1 "\t" $col "\t" $8 "\t" $2 }' "$PKG_TABLE"
}
# opt_features NIVEL → «clave<TAB>nombre<TAB>ids» de las funciones con filas de ese nivel (columna 9 + líneas #@función)
opt_features() {
  awk -F'\t' -v lvl="$1" '
    /^#@función\t/ { label[$2] = $3; order[++n] = $2; next }
    /^#/ || NF < 8 { next }
    $2 == lvl { k = ($9 == "" ? "otros" : $9); ids[k] = ids[k] (ids[k] == "" ? "" : " ") $1 }
    END { for (i = 1; i <= n; i++) if (order[i] in ids) printf "%s\t%s\t%s\n", order[i], label[order[i]], ids[order[i]]
          if ("otros" in ids) printf "otros\totros\t%s\n", ids["otros"] }' "$PKG_TABLE"
}
collect_packages() {
  local levels="base required recommended" id pk desc lvl p list k label ids
  # Opcionales: con --full, o preguntando una vez
  while IFS=$'\t' read -r id pk desc lvl; do OPTIONAL_IDS+=("$id"); done < <(read_table optional)
  if [ "$FULL" = 1 ]; then WANT_OPTIONAL=1
  elif [ "$YES" = 0 ] && [ "$DRY" = 0 ]; then
    say "Opcionales (${#OPTIONAL_IDS[@]}): $(opt_features optional | awk -F'\t' '{ printf "%s%s", (NR > 1 ? " · " : ""), $2 }')"
    ask "¿Instalar también los opcionales?" n && WANT_OPTIONAL=1
  fi
  [ "$WANT_OPTIONAL" = 1 ] && levels="$levels optional"
  [ "$WANT_GREETD" = 1 ] && levels="$levels greeter"
  if [ "$WANT_OPTIONAL" = 0 ]; then
    skip_ "opcionales (${#OPTIONAL_IDS[@]}; todos con --full). Añade luego lo que quieras con  hf-deps install <función>  (estado: hf-deps status):"
    while IFS=$'\t' read -r k label ids; do skip_ "  $k — $label: $ids"; done < <(opt_features optional)
  fi
  # «manual»: solo para cierto hardware o arranque; nunca se instala sola
  ids="$(opt_features manual | cut -f3 | tr '\n' ' ')"
  [ -n "${ids// /}" ] && skip_ "según hardware (no se instalan solos, ni con --full): ${ids% } → hf-deps install <id>"
  while IFS=$'\t' read -r id pk desc lvl; do
    # Sin fuente válida (p. ej. Hyprland demasiado antiguo en los repos): no se instala la versión vieja
    case "$id" in
      hyprland)   [ "$HYPR_MANUAL" = 1 ] && { NOPKG+=("$id"); continue; } ;;
      quickshell) [ "$QS_MANUAL" = 1 ] && { NOPKG+=("$id"); continue; } ;;
    esac
    if [ "$pk" = - ] || [ -z "$pk" ]; then
      [ "$lvl" = base ] && continue   # «-» en base = no hace falta en esa familia
      case " ${EXTRA_PKGS[*]} " in *" $id "*) continue ;; esac
      NOPKG+=("$id"); continue
    fi
    IFS=, read -ra list <<< "$pk"
    for p in "${list[@]}"; do
      case "$p" in aur:*) AURPKGS+=("${p#aur:}") ;; *) PKGS+=("$p") ;; esac
    done
  done < <(read_table $levels)
  PKGS+=(${EXTRA_PKGS[@]+"${EXTRA_PKGS[@]}"})
  return 0
}
# Quita los que no están en los repositorios activos (solo en el sistema real)
filter_available() {
  [ "$PROBE" = 1 ] || return 0
  local ok=() miss=() p avail
  say "Comprobando qué paquetes hay en tus repositorios…"
  case "$FAMILY" in
    fedora|rhel) avail="$(dnf -q repoquery --qf '%{name}\n' "${PKGS[@]}" 2>/dev/null | sort -u)" ;;
  esac
  for p in "${PKGS[@]}"; do
    case "$FAMILY" in
      arch)          pacman -Si -- "$p" >/dev/null 2>&1 || pacman -Sg -- "$p" >/dev/null 2>&1 ;;
      fedora|rhel)   grep -qx -- "$p" <<< "$avail" || rpm -q --whatprovides "$p" >/dev/null 2>&1 ;;
      suse|suse-leap) zypper --no-refresh -q -n what-provides "$p" 2>/dev/null | grep -q '|' ;;
      debian|ubuntu) [ -n "$(apt-cache policy -- "$p" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -v '(none)')" ] ;;
      void)          xbps-query -R -- "$p" >/dev/null 2>&1 ;;
    esac && ok+=("$p") || miss+=("$p")
  done
  # Fedora: si ya tienes el ffmpeg completo de RPM Fusion, no se cambia por ffmpeg-free
  if [ "$FAMILY" = fedora ] && rpm -q ffmpeg >/dev/null 2>&1; then
    local k=(); for p in ${ok[@]+"${ok[@]}"}; do [ "$p" = ffmpeg-free ] || k+=("$p"); done; ok=(${k[@]+"${k[@]}"})
  fi
  PKGS=(${ok[@]+"${ok[@]}"})
  [ ${#miss[@]} -gt 0 ] && { warn "No están en tus repositorios (se saltan): ${miss[*]}"; skip_ "sin paquete en tus repos: ${miss[*]}"; }
  return 0
}
install_packages() {
  local y=()
  if [ ${#PKGS[@]} -gt 0 ]; then
    say "Paquetes (${#PKGS[@]}):"
    case "$PM" in
      pacman)       [ "$YES" = 1 ] && y=(--noconfirm); root pacman -Syu --needed ${y[@]+"${y[@]}"} "${PKGS[@]}" ;;   # Arch no admite actualizaciones parciales
      dnf)          [ "$YES" = 1 ] && y=(-y); root dnf install ${y[@]+"${y[@]}"} "${PKGS[@]}" ;;
      zypper)       [ "$YES" = 1 ] && y=(--non-interactive); root zypper ${y[@]+"${y[@]}"} install "${PKGS[@]}" ;;
      apt-get)      [ "$YES" = 1 ] && y=(-y); root apt-get install ${y[@]+"${y[@]}"} "${PKGS[@]}" ;;
      xbps-install) [ "$YES" = 1 ] && y=(-y); root xbps-install -S ${y[@]+"${y[@]}"} "${PKGS[@]}" ;;
    esac && done_ "paquetes: ${PKGS[*]}" || { warn "El gestor de paquetes falló; sigo con el resto."; todo_ "revisa la instalación de paquetes ($PM)"; }
  fi
  if [ ${#AURPKGS[@]} -gt 0 ]; then
    if [ -n "$AURH" ]; then
      [ "$YES" = 1 ] && y=(--noconfirm) || y=()
      run "$AURH" -S --needed ${y[@]+"${y[@]}"} "${AURPKGS[@]}" && done_ "AUR ($AURH): ${AURPKGS[*]}" || warn "$AURH falló con: ${AURPKGS[*]}"
    else
      warn "Paquetes de AUR (${AURPKGS[*]}) y no hay paru ni yay."
      if ask "¿Instalar paru (compila paru-bin desde AUR; necesita base-devel y git)?" n; then
        local tmp; tmp="$(mktemp -d 2>/dev/null || echo /tmp/hf-paru)"
        root pacman -S --needed base-devel git
        run git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
        if [ "$DRY" = 1 ]; then printf '  [dry-run] (cd %q && makepkg -si)\n' "$tmp/paru-bin"; else (cd "$tmp/paru-bin" && makepkg -si); fi
        run paru -S --needed "${AURPKGS[@]}" && done_ "AUR (paru): ${AURPKGS[*]}"
      else
        skip_ "AUR: ${AURPKGS[*]}"
        todo_ "AUR (${AURPKGS[*]}): sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si && paru -S ${AURPKGS[*]}"
      fi
    fi
  fi
  return 0
}
# matugen: si no hay paquete, con cargo en ~/.local/bin
ensure_matugen() {
  local need=0
  if [ "$PROBE" = 1 ] && [ "$DRY" = 0 ]; then have matugen || need=1
  else case " ${NOPKG[*]} " in *" matugen "*) need=1 ;; esac; fi
  [ "$need" = 1 ] || return 0
  local n keep=(); for n in ${NOPKG[@]+"${NOPKG[@]}"}; do [ "$n" = matugen ] || keep+=("$n"); done; NOPKG=(${keep[@]+"${keep[@]}"})
  say "matugen (colores desde el fondo) no tiene paquete aquí: se puede compilar con cargo en ~/.local/bin."
  if ! ask "¿Compilar matugen con cargo (tarda unos minutos)?" s; then
    skip_ "matugen"; todo_ "matugen: cargo install --locked --root ~/.local matugen  (sin él se usan las paletas del diseño)"; return 0
  fi
  if ! have cargo || [ "$PROBE" = 0 ]; then
    case "$PM" in
      pacman) root pacman -S --needed rust ;; dnf) root dnf install -y cargo ;; zypper) root zypper --non-interactive install cargo ;;
      apt-get) root apt-get install -y cargo ;; xbps-install) root xbps-install -Sy cargo ;;
      *) [ "$PROBE" = 1 ] && { todo_ "instala Rust (https://rustup.rs) y luego: cargo install --locked --root ~/.local matugen"; return 0; } ;;
    esac
  fi
  if run cargo install --locked --root "$HOME/.local" matugen; then done_ "matugen (cargo, ~/.local/bin)"
  else warn "cargo no pudo compilar matugen (¿Rust demasiado antiguo?). Prueba con rustup: https://rustup.rs"; todo_ "matugen con rustup + cargo install --locked --root ~/.local matugen"; fi
  return 0
}

ensure_hyprland_version() {
  hdr "Hyprland ≥ $MIN_HYPR"
  if [ "$SIMULATED" = 1 ]; then
    echo "  [dry-run] comprobaría: Hyprland --version ≥ $MIN_HYPR, start-hyprland y qs --version ≥ $MIN_QS"
    if [ "$HYPR_MANUAL" = 1 ]; then warn "En esta distro Hyprland ≥ $MIN_HYPR no se instala solo:"; hypr_help; todo_ "Hyprland ≥ $MIN_HYPR: ver las instrucciones de arriba"; fi
    if [ "$QS_MANUAL" = 1 ]; then warn "Quickshell no tiene paquete aquí: compílalo (https://quickshell.org/docs/master/guide/install-setup/, «Manual build»)."; todo_ "Quickshell ≥ $MIN_QS: compilar desde quickshell.org"; fi
    return 0
  fi
  local v=""
  if have Hyprland; then v="$(Hyprland --version 2>/dev/null | grep -oE 'Hyprland [0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | cut -d' ' -f2 || true)"; fi
  if [ -z "$v" ]; then
    warn "Hyprland no está instalado. Cómo conseguir ≥ $MIN_HYPR aquí:"; hypr_help
    todo_ "instalar Hyprland ≥ $MIN_HYPR (ver arriba)"
  elif ! version_ge "$v" "$MIN_HYPR"; then
    warn "Tienes Hyprland $v: hyprfrijol necesita $MIN_HYPR o posterior (la configuración es Lua). Cómo actualizar:"; hypr_help
    todo_ "actualizar Hyprland $v → ≥ $MIN_HYPR"
  else
    say "Hyprland $v ✓"
    have start-hyprland || { warn "Falta start-hyprland (viene con Hyprland ≥ 0.53; hf-session lo usa)."; todo_ "start-hyprland (paquete de Hyprland incompleto)"; }
  fi
  local q=""
  have qs && q="$(qs --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
  if [ -z "$q" ]; then warn "Quickshell no está instalado: https://quickshell.org/docs/master/guide/install-setup/"; todo_ "instalar Quickshell ≥ $MIN_QS"
  elif ! version_ge "$q" "$MIN_QS"; then warn "Quickshell $q es antiguo: hyprfrijol está probado con $MIN_QS o posterior."; todo_ "actualizar Quickshell $q → ≥ $MIN_QS"
  else say "Quickshell $q ✓"; fi
  return 0
}

# ---------- Sistema mínimo: sesión sin escritorio ----------
system_setup() {
  hdr "Sistema (sesión sin escritorio)"
  local u; u="$(id -un)"
  # 1. logind / seatd
  case "$INIT" in
    systemd) if [ "$PROBE" = 0 ] || have loginctl; then say "logind (systemd) ✓"; else warn "Sin loginctl: Hyprland necesita logind o seatd."; fi ;;
    runit)
      say "runit: D-Bus, elogind y polkitd como servicios"
      local s; for s in dbus elogind polkitd; do svc_enabled "$s" && say "$s ✓" || { svc_enable "$s" && done_ "servicio $s"; }; done
      svc_enabled seatd && warn "seatd y elogind a la vez: deja solo elogind (sudo rm /var/service/seatd)" ;;
    openrc)
      todo_ "OpenRC: sudo rc-update add dbus default && sudo rc-update add elogind boot (o seatd + grupo seat)"
      warn "OpenRC: activa dbus y elogind (o seatd) a mano: sudo rc-update add dbus default && sudo rc-update add elogind boot" ;;
    *) warn "Sistema de arranque desconocido: necesitas D-Bus y logind/elogind o seatd en marcha." ;;
  esac
  # 2. Grupos: video (brillo con brightnessctl). input/seat no hacen falta con logind; con seatd solo, el de seatd.
  local g groups=(video)
  if [ "$INIT" != systemd ] && [ "$PROBE" = 1 ] && ! have loginctl && svc_enabled seatd; then
    for g in seat _seatd; do getent group "$g" >/dev/null && groups+=("$g"); done
  fi
  for g in "${groups[@]}"; do
    if [ "$PROBE" = 1 ] && ! getent group "$g" >/dev/null; then continue; fi
    if [ "$PROBE" = 1 ] && id -nG "$u" | tr ' ' '\n' | grep -qx "$g"; then say "grupo $g ✓"; continue; fi
    root usermod -aG "$g" "$u" && done_ "grupo $g (vale tras volver a iniciar sesión)"
  done
  # 3. Tarjeta gráfica
  gpu_hint
  # 4. PipeWire
  if [ "$INIT" = systemd ]; then
    local unit todo=()
    for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
      if [ "$PROBE" = 1 ] && systemctl --user is-enabled --quiet "$unit" 2>/dev/null; then continue; fi
      todo+=("$unit")
    done
    if [ ${#todo[@]} -eq 0 ]; then say "PipeWire (servicios de usuario) ✓"
    elif [ "$PROBE" = 1 ] && ! systemctl --user show-environment >/dev/null 2>&1; then
      todo_ "PipeWire: systemctl --user enable --now ${todo[*]}  (desde tu sesión)"
    else run systemctl --user enable --now "${todo[@]}" && done_ "PipeWire: ${todo[*]}"; fi
  elif [ "$FAMILY" = void ]; then
    # Void: wireplumber y pipewire-pulse los arranca pipewire; a pipewire lo lanza la sesión (autostart.lua)
    local d=/etc/pipewire/pipewire.conf.d
    if [ "$PROBE" = 1 ] && [ -e "$d/10-wireplumber.conf" ]; then say "PipeWire (conf.d) ✓"; else
      root mkdir -p "$d"
      root ln -sfn /usr/share/examples/wireplumber/10-wireplumber.conf "$d/10-wireplumber.conf"
      root ln -sfn /usr/share/examples/pipewire/20-pipewire-pulse.conf "$d/20-pipewire-pulse.conf"
      done_ "PipeWire: wireplumber y pipewire-pulse en $d"
    fi
  fi
  # 5. NetworkManager (sin desactivar en silencio otro gestor de red)
  network_setup
  # 6. Otros servicios del sistema: energía y Bluetooth
  if [ "$INIT" = systemd ]; then
    if svc_active tlp || svc_active tuned; then warn "tlp/tuned activo: no activo power-profiles-daemon (chocan)."
    elif [ "$PROBE" = 0 ] || { have powerprofilesctl && ! svc_enabled power-profiles-daemon && ! svc_active power-profiles-daemon; }; then svc_enable power-profiles-daemon --now && done_ "servicio power-profiles-daemon"; fi
    if [ "$WANT_OPTIONAL" = 1 ] && { [ "$PROBE" = 0 ] || { have bluetoothctl && ! svc_enabled bluetooth && ! svc_active bluetooth; }; }; then svc_enable bluetooth --now && done_ "servicio bluetooth"; fi
    # Impresoras (Ajustes › Impresoras): CUPS por socket, arranca solo al imprimir
    if [ "$PROBE" = 0 ] || { have lpstat && ! svc_enabled cups.socket && ! svc_enabled cups && ! svc_active cups; }; then svc_enable cups.socket --now && done_ "servicio cups (impresoras)"; fi
  fi
  # 7. polkit (el agente lo pone el shell; aquí solo el servicio)
  if [ "$PROBE" = 1 ] && ! have pkexec && ! [ -x /usr/lib/polkit-1/polkitd ] && ! [ -x /usr/libexec/polkitd ]; then warn "polkit no está instalado: las acciones de administrador no pedirán contraseña."; fi
  # 8. Carpetas del usuario (Imágenes, Descargas…)
  if [ "$PROBE" = 0 ] || have xdg-user-dirs-update; then run xdg-user-dirs-update && done_ "carpetas del usuario (xdg-user-dirs)"; fi
  return 0
}
gpu_hint() {
  [ "$PROBE" = 1 ] || { echo "  [dry-run] comprobaría /dev/dri y el fabricante de la GPU (NVIDIA → aviso de drivers)"; return 0; }
  if ! ls /dev/dri/card* >/dev/null 2>&1; then
    warn "No hay /dev/dri: sin GPU (o una VM sin aceleración) Hyprland no arranca. En una VM activa virtio-gpu con 3D."
    todo_ "GPU: no hay /dev/dri (servidor o VM sin aceleración)"; return 0
  fi
  if grep -qs 0x10de /sys/class/drm/card*/device/vendor && [ -d /sys/module/nvidia_drm ]; then
    say "GPU NVIDIA con el driver nvidia_drm cargado ✓ (si algo falla: https://wiki.hypr.land/Nvidia/)"
  elif grep -qs 0x10de /sys/class/drm/card*/device/vendor; then
    warn "GPU NVIDIA: necesitas su driver con KMS (nvidia_drm.modeset=1). Guía: https://wiki.hypr.land/Nvidia/"
    case "$FAMILY" in
      arch)   note "sudo pacman -S nvidia-open-dkms nvidia-utils (o nvidia-open para el kernel estándar)" ;;
      fedora) note "RPM Fusion: sudo dnf install akmod-nvidia" ;;
      suse*)  note "sudo zypper install openSUSE-repos-NVIDIA && sudo zypper install-new-recommends" ;;
      debian|ubuntu) note "Debian: sudo apt-get install nvidia-driver · Ubuntu: sudo ubuntu-drivers install" ;;
      void)   note "sudo xbps-install -S void-repo-nonfree && sudo xbps-install -S nvidia" ;;
    esac
    todo_ "GPU NVIDIA: driver propietario con KMS"
  else say "GPU con driver abierto (Mesa) ✓"; fi
  return 0
}
network_setup() {
  local other="" s
  if [ "$INIT" = systemd ]; then
    if svc_active NetworkManager; then say "NetworkManager ✓"; return 0; fi
    for s in systemd-networkd networking wicked connman netctl dhcpcd iwd; do svc_active "$s" && { other="$s"; break; }; done
    if [ -n "$other" ]; then
      warn "La red la gestiona $other: no activo NetworkManager (el panel de red no podrá cambiarla)."
      note "Para pasarte (desde la consola, no por SSH): sudo systemctl disable --now $other && sudo systemctl enable --now NetworkManager"
      todo_ "red: gestionada por $other (NetworkManager sin activar)"; return 0
    fi
    [ "$PROBE" = 0 ] && echo "  [dry-run] si ningún otro gestor de red está activo (systemd-networkd, networking, wicked, connman, netctl, dhcpcd, iwd):"
    svc_enable NetworkManager --now && done_ "servicio NetworkManager"
  elif [ "$INIT" = runit ]; then
    svc_enabled NetworkManager && { say "NetworkManager ✓"; return 0; }
    for s in dhcpcd wpa_supplicant connmand iwd; do svc_enabled "$s" && { other="$s"; break; }; done
    if [ -n "$other" ]; then
      warn "La red la gestiona $other: no activo NetworkManager."
      note "Para pasarte: sudo rm /var/service/$other && sudo ln -s /etc/sv/NetworkManager /var/service/"
      todo_ "red: gestionada por $other"; return 0
    fi
    svc_enable NetworkManager && done_ "servicio NetworkManager"
  else
    todo_ "red: activa NetworkManager en tu sistema de arranque"
  fi
  return 0
}

# ---------- Login (greetd) ----------
# Guarda el gestor anterior en /etc/greetd/hf-previous-dm para poder volver con --greeter-off.
greeter_sync() {   # (en --dry-run solo se enseña: hf-greeter-sync --dry-run sí prepara archivos temporales)
  run env HF_ROOT="$HERE" HF_PRIV="${SUDO[*]:-sudo}" "$HERE/scripts/hf-greeter-sync" || warn "No se pudo sincronizar el tema del login (prueba: scripts/hf-greeter-sync --dry-run)"
}
greeter() {
  local PREV_FILE=/etc/greetd/hf-previous-dm
  [ -e "$PREV_FILE" ] || [ ! -e /etc/greetd/hl-previous-dm ] || PREV_FILE=/etc/greetd/hl-previous-dm   # nombre anterior (hypr-liquid)
  if [ "$FAMILY" = nixos ]; then
    warn "NixOS: el login se declara en configuration.nix:"
    note "services.greetd = { enable = true; settings.default_session = { command = \"start-hyprland -- --config /etc/greetd/hyprland-greeter.lua\"; user = \"greeter\"; }; };" \
         "environment.etc.\"greetd/hyprland-greeter.lua\".source = $HERE/greeter/hyprland-greeter.lua;  (y greeter/quickshell en /etc/greetd/quickshell)"
    exit 0
  fi
  if [ "$1" = sync ]; then greeter_sync; exit 0; fi
  if [ "$1" = off ]; then
    local prev; prev="$(cat "$PREV_FILE" 2>/dev/null || true)"
    [ -n "$prev" ] || { warn "No sé qué gestor había antes. Actívalo a mano (systemd: sudo systemctl enable --force <sddm|gdm|…>)."; exit 1; }
    svc_disable greetd
    if [ "$INIT" = systemd ]; then root systemctl enable --force "$prev"; else svc_enable "$prev"; fi
    [ -f /etc/greetd/config.toml.antes-hyprfrijol ] && root cp /etc/greetd/config.toml.antes-hyprfrijol /etc/greetd/config.toml
    say "Vuelve a usarse $prev al reiniciar."
    exit 0
  fi
  hdr "Login visual (greetd)"
  if [ "$DEPS" = 1 ] && [ -n "$PM" ] && { [ "$DRY" = 1 ] || ! have greetd; }; then
    WANT_GREETD=1; PKGS=() NOPKG=() AURPKGS=()
    while IFS=$'\t' read -r _ pk _ _; do IFS=, read -ra l <<< "$pk"; PKGS+=("${l[@]}"); done < <(read_table greeter)
    install_packages
  fi
  have greetd || [ "$DRY" = 1 ] || { warn "Falta greetd: instálalo con tu gestor de paquetes."; exit 1; }
  # Usuario con el que corre el login: greeter (Arch, openSUSE), _greetd (Debian/Ubuntu), greetd (Fedora), _greeter (Void)
  local gu=greeter u
  for u in greeter _greetd greetd _greeter; do getent passwd "$u" >/dev/null 2>&1 && { gu="$u"; break; }; done
  local cur; cur="$(current_dm)"
  [ "$PROBE" = 0 ] && echo "  [dry-run] si hay otro gestor de inicio activo (sddm, gdm, lightdm…): se guarda su nombre en $PREV_FILE y se desactiva"
  if [ -n "$cur" ] && [ "$cur" != greetd ]; then
    say "Gestor actual: $cur (se guarda para --greeter-off)"
    printf '%s\n' "$cur" | root_write "$PREV_FILE" 644
  fi
  root install -Dm644 "$HERE/greeter/hyprland-greeter.lua" /etc/greetd/hyprland-greeter.lua
  root install -d /etc/greetd/quickshell
  local f; for f in shell.qml Landscape.qml palettes.json; do root install -m644 "$HERE/greeter/quickshell/$f" "/etc/greetd/quickshell/$f"; done
  if [ "$DRY" = 1 ] || [ -f /etc/greetd/config.toml ]; then root cp -n /etc/greetd/config.toml /etc/greetd/config.toml.antes-hyprfrijol; fi
  printf '%s\n' '[terminal]' 'vt = 1' '' '[default_session]' \
    '# Login visual de hyprfrijol. Si fallara, desde otra TTY (Ctrl+Alt+F3):  ./install.sh --greeter-off' \
    'command = "start-hyprland -- --config /etc/greetd/hyprland-greeter.lua"' "user = \"$gu\"" | root_write /etc/greetd/config.toml 644
  # Que la contraseña del login desbloquee el llavero (si no, Chrome la pide al abrirse). optional: si falla, se entra igual.
  if compgen -G '/usr/lib*/security/pam_gnome_keyring.so' >/dev/null || compgen -G '/usr/lib/*/security/pam_gnome_keyring.so' >/dev/null || compgen -G '/lib/*/security/pam_gnome_keyring.so' >/dev/null \
     && [ -f /etc/pam.d/greetd ] && ! grep -q pam_gnome_keyring /etc/pam.d/greetd; then
    { cat /etc/pam.d/greetd 2>/dev/null; printf '%s\n' 'auth       optional     pam_gnome_keyring.so' 'session    optional     pam_gnome_keyring.so auto_start'; } | root_write /etc/pam.d/greetd 644
  fi
  if [ -n "$cur" ] && [ "$cur" != greetd ]; then svc_disable "$cur"; fi
  svc_enable greetd
  greeter_sync
  say "Login de hyprfrijol activado para el próximo arranque (reinicia para verlo). Para volver: ./install.sh --greeter-off"
  say "Si cambias de tema o de fondo, vuelve a copiarlo al login con: hf-greeter-sync"
  exit 0
}

# ---------- Instalación de usuario ----------
SCRIPTS=()
for f in "$HERE"/scripts/hf-*; do [ -f "$f" ] && SCRIPTS+=("$(basename "$f")"); done
user_install() {
  hdr "Instalación de usuario"
  run mkdir -p "$BIN" "$USERCFG" "$STATE"
  local s linked=0
  for s in "${SCRIPTS[@]}"; do
    [ -x "$HERE/scripts/$s" ] || run chmod +x "$HERE/scripts/$s"
    if [ -e "$BIN/$s" ] && [ ! -L "$BIN/$s" ]; then warn "$BIN/$s existe y no es un enlace: no lo toco"; continue; fi
    [ -L "$BIN/$s" ] && [ "$(readlink "$BIN/$s")" = "$HERE/scripts/$s" ] && continue
    run ln -sfn "$HERE/scripts/$s" "$BIN/$s"; linked=$((linked + 1))
  done
  say "Scripts en ~/.local/bin → $HERE/scripts (${#SCRIPTS[@]}, $linked nuevos o actualizados)"
  done_ "enlaces ~/.local/bin/hf-* → $HERE/scripts"
  case ":$PATH:" in *":$BIN:"*) ;; *) warn "~/.local/bin no está en tu PATH: añádelo en tu ~/.profile (dentro de la sesión no hace falta)." ;; esac
  # Configuración inicial (nunca se sobrescribe)
  [ -e "$USERCFG/local.lua" ] || { run cp "$HERE/config/defaults/local.lua" "$USERCFG/local.lua"; done_ "~/.config/hyprfrijol/local.lua (plantilla)"; }
  [ -e "$STATE/colors.json" ] || run cp "$HERE/config/defaults/colors.json" "$STATE/colors.json"
  # Entrada de sesión para el gestor de inicio
  if [ "$SESSION" = 1 ] && [ "$FAMILY" = nixos ]; then
    warn "NixOS: /usr/share es de solo lectura; arranca con hf-session desde una TTY o declara la sesión en tu configuración."
  elif [ "$SESSION" = 1 ]; then
    local want; want="$(printf '%s\n' '[Desktop Entry]' 'Name=Hyprland (HyprFrijol)' 'Comment=Hyprland con el shell HyprFrijol' \
      "Exec=$BIN/hf-session" 'Type=Application' 'DesktopNames=Hyprland' 'Keywords=tiling;wayland;compositor;')"
    if [ -f "$SESSION_FILE" ] && [ "$(cat "$SESSION_FILE")" = "$want" ]; then say "Entrada de sesión ✓"
    else say "Entrada de sesión $SESSION_FILE (pide sudo)"; printf '%s\n' "$want" | root_write "$SESSION_FILE" 644 && done_ "entrada de sesión «Hyprland (HyprFrijol)»"; fi
    # Modo seguro: Hyprland mínimo sin shell, plugins ni local.lua, con el menú «Restaurar ajustes» (hf-safe)
    want="$(printf '%s\n' '[Desktop Entry]' 'Name=HyprFrijol (modo seguro)' 'Comment=Hyprland mínimo para reparar HyprFrijol: sin shell ni plugins' \
      "Exec=$BIN/hf-session --safe" 'Type=Application' 'DesktopNames=Hyprland' 'Keywords=recovery;safe;rescue;')"
    if [ -f "$SAFE_SESSION_FILE" ] && [ "$(cat "$SAFE_SESSION_FILE")" = "$want" ]; then say "Entrada de modo seguro ✓"
    else printf '%s\n' "$want" | root_write "$SAFE_SESSION_FILE" 644 && done_ "entrada de sesión «HyprFrijol (modo seguro)»"; fi
  else
    skip_ "entrada de sesión (--no-session)"
  fi
  # Colores iniciales a partir del fondo
  if [ "$DRY" = 0 ] && [ -z "${HF_NO_COLORS:-}" ] && have matugen; then
    "$HERE/scripts/hf-wallpaper" restore >/dev/null 2>&1 || warn "Pon imágenes en ~/Imágenes/Fondos (o ~/Imágenes/Wallpapers) y ejecuta hf-wallpaper next."
  fi
  return 0
}

# ---------- Desinstalar ----------
uninstall() {
  hdr "Desinstalar"
  local s l t
  for l in "$BIN"/hf-* "$BIN"/hl-*; do
    [ -L "$l" ] || continue
    t="$(readlink "$l")"
    case "$(basename "$l")" in
      hf-*) case "$t" in */scripts/"$(basename "$l")") run rm "$l" ;; esac ;;     # también si el repo se movió
      hl-*) case "$t" in hf-*|*/scripts/hf-*|*/scripts/hl-*) run rm "$l" ;; esac ;;   # enlaces de hf-migrate
    esac
  done
  done_ "enlaces de ~/.local/bin"
  # Lanzadores que crea el shell (web apps, firmar) y entradas de inicio
  for l in "$HOME"/.local/share/applications/hf-*.desktop "$HOME"/.config/autostart/hf-*.desktop; do
    [ -f "$l" ] && grep -qs 'hf-\|hyprfrijol' "$l" && run rm "$l"
  done
  have update-desktop-database && run update-desktop-database -q "$HOME/.local/share/applications" 2>/dev/null || true
  # Menú «HyprFrijol» de Nautilus (enlace de hf-apps extension); las apps instaladas se quedan (hf-apps remove …)
  l="$HOME/.local/share/nautilus-python/extensions/hyprfrijol.py"
  [ -L "$l" ] && case "$(readlink "$l")" in */config/nautilus/hyprfrijol.py) run rm "$l"; done_ "menú de Nautilus" ;; esac
  # La entrada de sesión es del sistema: solo se quita si arranca la sesión de ESTE usuario
  local sf
  for sf in "$SESSION_FILE" "$SAFE_SESSION_FILE" /usr/share/wayland-sessions/hypr-liquid.desktop; do   # (el último: nombre anterior)
    [ -e "$sf" ] || continue
    if grep -qsE "^Exec=$BIN/h[fl]-session( --safe)?\$" "$sf"; then root rm "$sf"; done_ "entrada de sesión $sf"
    else warn "$sf arranca la sesión de otro usuario o carpeta: no la toco"; fi
  done
  if [ -e /etc/greetd/hf-previous-dm ] || grep -qs hyprland-greeter /etc/greetd/config.toml; then
    warn "El login de hyprfrijol (greetd) sigue activo: vuelve a tu gestor con ./install.sh --greeter-off"
  fi
  if [ "$PURGE" = 1 ]; then
    if ask "¿Borrar también tus ajustes, estado y caché de hyprfrijol?" n || [ "$YES" = 1 ] || [ "$DRY" = 1 ]; then
      # Quita el tema de las apps (kitty, GTK, Qt, btop, iconos) antes de borrar el estado
      if [ -d "$USERCFG" ]; then run env HF_ROOT="$HERE" "$HERE/scripts/hf-apply" set themeApps=false themeIcons=false --no-reload || true; fi
      [ -x "$HOME/.local/bin/matugen" ] && [ -f "$HOME/.local/.crates.toml" ] && grep -qs '^"matugen ' "$HOME/.local/.crates.toml" && run cargo uninstall --root "$HOME/.local" matugen
      for s in "$USERCFG" "$STATE" "$HOME/.cache/hyprfrijol" "$HOME/.local/share/hyprfrijol" \
               "$HOME/.config/hypr-liquid" "$HOME/.local/state/hypr-liquid" "$HOME/.cache/hypr-liquid" "$HOME/.local/share/hypr-liquid"; do
        [ -e "$s" ] || [ -L "$s" ] || continue
        case "$HERE/" in "$s"/*) warn "No borro $s: contiene este repo"; continue ;; esac
        run rm -rf "$s"
      done
      done_ "ajustes, estado y caché"
    fi
  else
    say "Tus ajustes siguen en ~/.config/hyprfrijol y ~/.local/state/hyprfrijol (bórralos con --uninstall --purge)."
  fi
  say "Los paquetes del sistema no se desinstalan. El repo sigue en $HERE (bórralo si quieres)."
  return 0
}

# ---------- Resumen ----------
wrap() { printf '%s\n' "$1" | fold -s -w 104 | sed '1s/^/    /; 2,$s/^/        /'; }
summary() {
  hdr "Resumen"
  [ "$DRY" = 1 ] && echo "  (prueba: no se ha ejecutado nada)"
  echo "  Distro:     ${OS_PRETTY:-desconocida} · familia $FAMILY · ${PM:-sin gestor} · arranque $INIT"
  [ -n "$HYPR_SRC" ] && echo "  Hyprland:   $HYPR_SRC"
  [ -n "$QS_SRC" ]   && echo "  Quickshell: $QS_SRC"
  local x
  if [ ${#DONE[@]} -gt 0 ]; then echo "  ${C1}Hecho${C0}$([ "$DRY" = 1 ] && echo ' (se haría)'):"; for x in "${DONE[@]}"; do wrap "✓ $x"; done; fi
  if [ ${#SKIPPED[@]} -gt 0 ]; then echo "  ${C2}Saltado${C0}:"; for x in "${SKIPPED[@]}"; do wrap "– $x"; done; fi
  if [ ${#TODO[@]} -gt 0 ]; then echo "  ${C3}Te toca${C0}:"; for x in "${TODO[@]}"; do echo "    → $x"; done; fi
  echo
  if [ -n "${HAS_DM:-}" ]; then
    echo "  · Cierra sesión y elige «Hyprland (HyprFrijol)» en $HAS_DM, o pruébalo antes en una ventana: hf-session --nested"
  else
    echo "  · Sin gestor de inicio: entra en una TTY con tu usuario y ejecuta  hf-session"
    echo "    Para que arranque solo al entrar en tty1, añade a ~/.bash_profile (o ~/.profile):"
    echo "      [ -z \"\$WAYLAND_DISPLAY\" ] && [ \"\$(tty)\" = /dev/tty1 ] && exec \"\$HOME/.local/bin/hf-session\""
    echo "    O un login visual: ./install.sh --greeter"
  fi
  echo "  · Qué tiene cada función y qué falta: hf-deps status · añadir una: hf-deps install <función> (p. ej. impresoras)"
  echo "  · Tus ajustes: ~/.config/hyprfrijol/local.lua · Desinstalar: ./install.sh --uninstall"
}

# =================== Inicio ===================
detect_distro

if [ "$UNINSTALL" = 1 ]; then uninstall; exit 0; fi

# Migración desde hypr-liquid (nombre anterior). Solo aquí se crean los enlaces hl-* → hf-*.
if [ "$MIGRATE" = 1 ] || { [ -d "$HOME/.config/hypr-liquid" ] && [ ! -L "$HOME/.config/hypr-liquid" ]; } || compgen -G "$BIN/hl-*" >/dev/null; then
  say "Instalación anterior (hypr-liquid) encontrada: migrando a hyprfrijol"
  margs=(); [ "$DRY" = 1 ] && margs+=(--dry-run)
  "$HERE/scripts/hf-migrate" ${margs[@]+"${margs[@]}"} || warn "La migración no terminó (prueba: scripts/hf-migrate --dry-run)"
  [ "$MIGRATE" = 1 ] && exit 0
fi

say "hyprfrijol desde $HERE"
say "Distro: ${OS_PRETTY:-desconocida} · familia: $FAMILY · gestor: ${PM:-ninguno} · arranque: $INIT"
[ "$DRY" = 1 ] && say "Modo prueba (--dry-run): solo se enseñan los comandos."

[ -n "$GREETER" ] && greeter "$GREETER"

# ---------- Dependencias ----------
if [ "$DEPS" = 1 ]; then
  case "$FAMILY" in
    gentoo)
      hdr "Gentoo (a mano)"
      warn "No instalo paquetes en Gentoo. Overlays: hyproverlay (Hyprland) y guru (Quickshell, matugen, cliphist…):"
      note "sudo eselect repository enable hyproverlay guru && sudo emaint sync -r hyproverlay -r guru" \
           "sudo emerge --ask gui-wm/hyprland gui-apps/hyprlock gui-apps/hypridle gui-libs/xdg-desktop-portal-hyprland \\" \
           "     gui-apps/quickshell x11-misc/matugen gui-apps/wl-clipboard app-misc/jq media-video/pipewire net-misc/networkmanager" \
           "El resto de dependencias, por nombre, en install/packages.tsv."
      HYPR_SRC="hyproverlay" QS_SRC="guru (gui-apps/quickshell)"
      todo_ "Gentoo: instalar los paquetes de arriba (emerge)"; DEPS=0 ;;
    nixos)
      hdr "NixOS (declarativo)"
      warn "No instalo paquetes en NixOS. Añade a tu configuration.nix (o home-manager):"
      note "programs.hyprland.enable = true;" \
           "environment.systemPackages = with pkgs; [ quickshell matugen hyprlock hypridle hyprsunset hyprpicker" \
           "  wl-clipboard cliphist grim slurp wf-recorder wtype jq python3 kitty cava playerctl brightnessctl" \
           "  imagemagick ffmpeg tesseract libnotify zenity papirus-icon-theme mpvpaper ];" \
           "fonts.packages = with pkgs; [ inter noto-fonts noto-fonts-color-emoji jetbrains-mono ];" \
           "services.pipewire = { enable = true; pulse.enable = true; };  networking.networkmanager.enable = true;" \
           "services.upower.enable = true;  services.power-profiles-daemon.enable = true;  security.polkit.enable = true;"
      HYPR_SRC="nixpkgs (programs.hyprland)" QS_SRC="nixpkgs"
      todo_ "NixOS: añadir los paquetes a configuration.nix y nixos-rebuild switch"; DEPS=0; SYSTEM=0 ;;
    unknown)
      err "No reconozco esta distro (ID=${OS_ID:-?} ID_LIKE=${OS_LIKE:-?})."
      echo "  Instala a mano lo equivalente a esto (lista completa en install/packages.tsv):"
      awk -F'\t' '!/^#/ && NF>=8 && ($2=="required"||$2=="recommended") {printf "    %-12s %-18s %s\n", $2, $1, $8}' "$PKG_TABLE"
      echo "  Lo imprescindible: Hyprland ≥ $MIN_HYPR (con start-hyprland), Quickshell ≥ $MIN_QS, matugen, python3, jq, wl-clipboard."
      echo "  Después vuelve a ejecutar:  ./install.sh --no-deps"
      echo "  (o simula una familia conocida para ver los comandos: HF_DISTRO=arch|fedora|opensuse-tumbleweed|debian|void ./install.sh --dry-run)"
      exit 2 ;;
  esac
fi

if [ "$DEPS" = 1 ]; then
  hdr "Repositorios"
  setup_sources
  hdr "Paquetes"
  collect_packages
  filter_available
  install_packages
  ensure_matugen
  [ ${#NOPKG[@]} -gt 0 ] && skip_ "sin paquete en $FAMILY: ${NOPKG[*]}"
else
  [ "$FAMILY" = gentoo ] || [ "$FAMILY" = nixos ] || skip_ "paquetes (--no-deps)"
fi

ensure_hyprland_version

if [ "$SYSTEM" = 1 ] && [ "$FAMILY" != nixos ]; then system_setup
elif [ "$FAMILY" != nixos ]; then skip_ "servicios y grupos (--no-system)"; fi

user_install

# ---------- Apps por nivel (install/apps.json → scripts/hf-apps) ----------
apps_install() {
  local tiers="$APPS" ans a=()
  if [ -z "$tiers" ]; then
    tiers=serie
    if [ "$YES" = 0 ] && [ "$DRY" = 0 ]; then
      say "Apps de hyprfrijol por nivel (lista: scripts/hf-apps list):"
      note "serie          Nautilus, kitty, Chrome, Editor de texto, Loupe, Papers, Showtime/Decibels, File Roller, Calculadora, Discos, Resources, Pika Backup, Bazaar" \
           "productividad  ONLYOFFICE, Thunderbird, KeePassXC, LocalSend, Parabolic, VS Code" \
           "destacada      Morrow (notas), Sung (música, se compila), Orchard (Apple Music, beta), Heronite (juegos)" \
           "creativa       darktable, GIMP, Inkscape, Kdenlive" \
           "experimental   WordCraft, GridCraft, DeckCraft (ArtCraft, en desarrollo)"
      printf '%s?%s ¿Qué niveles instalo? (separados por comas; «none» para ninguno) [serie] ' "$C1" "$C0"
      { read -r ans </dev/tty; } 2>/dev/null || ans=""
      tiers="${ans:-serie}"; tiers="${tiers// /}"
    fi
  fi
  [ "$tiers" = none ] && { skip_ "apps por nivel (--apps=none)"; return 0; }
  hdr "Apps ($tiers)"
  [ "$DRY" = 1 ] && a+=(--dry-run)
  [ "$YES" = 1 ] && a+=(--yes)
  if HF_ROOT="$HERE" "$HERE/scripts/hf-apps" install "$tiers" ${a[@]+"${a[@]}"}; then done_ "apps: $tiers (hf-apps)"
  else warn "Alguna app no se instaló: revisa arriba o usa Ajustes › Aplicaciones"; todo_ "apps: hf-apps install $tiers"; fi
  return 0
}
[ "$DEPS" = 1 ] && apps_install || { [ "$DEPS" = 0 ] && skip_ "apps por nivel (--no-deps)"; }
HAS_DM="$(current_dm)"; [ "$HAS_DM" = greetd ] && HAS_DM="el login (greetd)"
summary
