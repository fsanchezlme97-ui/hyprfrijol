#!/usr/bin/env bash
# hyprfrijol — instalación en una línea: descarga el repo y ejecuta ./install.sh
#
#   curl -fsSL https://raw.githubusercontent.com/fsanchezlme97-ui/hyprfrijol/main/install/bootstrap.sh | bash
#   curl -fsSL …/bootstrap.sh | bash -s -- --dry-run          (cualquier opción de install.sh: --yes, --full, --greeter…)
#
# Variables:
#   HF_DIR     dónde se descarga (por defecto ~/.local/src/hyprfrijol; ~/.local/share/hyprfrijol no, que es la
#              carpeta de datos de hyprfrijol)
#   HF_REPO    repositorio git (por defecto https://github.com/fsanchezlme97-ui/hyprfrijol)
#   HF_BRANCH  rama (por defecto main)
#
# Si ya está descargado, lo actualiza (git pull --ff-only) y vuelve a ejecutar el instalador, que se puede repetir.
set -euo pipefail

REPO="${HF_REPO:-https://github.com/fsanchezlme97-ui/hyprfrijol}"
BRANCH="${HF_BRANCH:-main}"
DIR="${HF_DIR:-$HOME/.local/src/hyprfrijol}"

say()  { printf '\033[1;36m▸\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" != 0 ] || [ -n "${HF_ALLOW_ROOT:-}" ] || die "Ejecútalo con tu usuario, no como root (el instalador pide sudo cuando hace falta)."
case "$REPO" in */OWNER/*) die "Este bootstrap aún tiene el marcador OWNER. Usa: HF_REPO=https://github.com/<usuario>/hyprfrijol bash bootstrap.sh" ;; esac

if [ -d "$DIR/.git" ]; then
  say "Actualizando $DIR"
  # hf-update deja el clon en una versión suelta (sin rama): se vuelve a la rama antes de traer lo nuevo
  git -C "$DIR" symbolic-ref -q HEAD >/dev/null || git -C "$DIR" checkout -q "$BRANCH" 2>/dev/null || true
  git -C "$DIR" pull --ff-only || say "No se pudo actualizar (¿cambios locales?): sigo con lo que hay"
elif [ -e "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; then
  die "$DIR ya existe y no es un clon de git. Bórralo o elige otra carpeta con HF_DIR=…"
elif command -v git >/dev/null; then
  say "Descargando $REPO ($BRANCH) en $DIR"
  mkdir -p "$(dirname "$DIR")"
  git clone --branch "$BRANCH" "$REPO" "$DIR"
else
  # Sin git (instalación mínima): el tarball de GitHub. Para actualizar después, instala git y vuelve a clonar.
  command -v curl >/dev/null || command -v wget >/dev/null || die "Necesito git, curl o wget."
  command -v tar >/dev/null || die "Necesito tar (o git)."
  say "git no está instalado: descargo el archivo de la rama $BRANCH"
  mkdir -p "$DIR"
  url="${REPO%.git}/archive/refs/heads/$BRANCH.tar.gz"
  if command -v curl >/dev/null; then curl -fsSL "$url"; else wget -qO- "$url"; fi | tar -xz -C "$DIR" --strip-components=1
fi

[ -x "$DIR/install.sh" ] || die "No encuentro $DIR/install.sh"
# Con «curl | bash» la entrada estándar es el propio script: las preguntas (y las del gestor de paquetes) van a la terminal.
if [ -t 0 ]; then exec "$DIR/install.sh" "$@"
elif { : </dev/tty; } 2>/dev/null; then exec "$DIR/install.sh" "$@" </dev/tty
else say "Sin terminal: modo no interactivo (--yes)"; exec "$DIR/install.sh" --yes "$@"; fi
