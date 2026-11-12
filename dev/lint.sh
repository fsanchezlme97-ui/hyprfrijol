#!/usr/bin/env bash
# dev/lint.sh — revisión estática de todo el repo, rápida (segundos) y sin sesión gráfica:
#   · sintaxis: bash -n (scripts bash), py_compile (python), luac -p (config de Hyprland en Lua)
#   · shellcheck (avisos y errores) y pyflakes, si están instalados; si no, lo dice y sigue
#   · JSON del repo (jq)
#   · dev/coherencia.py: claves de ajustes con valor por defecto y programas en install/packages.tsv
# Sale con 0 si todo bien, 1 si algo falla. Complemento: dev/check.sh (abre todas las vistas en una sesión anidada).
#
# Para tener shellcheck y pyflakes sin tocar el sistema:
#   python3 -m venv ~/.cache/hf-lint && ~/.cache/hf-lint/bin/pip install shellcheck-py pyflakes
# (dev/lint.sh los busca también ahí)
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$ROOT" || exit 1
PATH="$PATH:$HOME/.cache/hf-lint/bin"
fail=0
bad() { printf '\033[1;31m✗\033[0m %s\n' "$*"; fail=1; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
note() { printf '\033[1;33m·\033[0m %s\n' "$*"; }

SH=(); PY=()
for f in scripts/* install.sh install/*.sh dev/*; do
  [ -f "$f" ] || continue
  case "$(head -n1 "$f")" in *python*) PY+=("$f") ;; *bash*|*/sh*) SH+=("$f") ;; esac
done

# ── Sintaxis ──
n=0; for f in "${SH[@]}"; do bash -n "$f" 2>&1 | sed "s|^|  |" | grep . && { bad "bash -n $f"; n=1; }; done
[ "$n" = 0 ] && ok "bash -n: ${#SH[@]} scripts"
n=0; for f in "${PY[@]}"; do python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$f" 2>&1 | sed "s|^|  |" | grep . && { bad "python $f"; n=1; }; done
[ "$n" = 0 ] && ok "python: ${#PY[@]} scripts"
if command -v luac >/dev/null; then
  n=0; while IFS= read -r f; do luac -p "$f" 2>&1 | sed "s|^|  |" | grep . && { bad "luac $f"; n=1; }; done < <(find config greeter -name '*.lua')
  [ "$n" = 0 ] && ok "luac -p: config de Hyprland"
else note "sin luac: no reviso los .lua"; fi
n=0; while IFS= read -r f; do jq -e . "$f" >/dev/null 2>&1 || { bad "JSON roto: $f"; n=1; }; done < <(git ls-files '*.json')
[ "$n" = 0 ] && ok "JSON del repo"
if out="$(python3 dev/coherencia.py 2>&1)"; then ok "ajustes con valor por defecto y dependencias en packages.tsv"
else bad "coherencia:"; printf '%s\n' "$out" | sed 's|^|  |'; fi
python3 dev/gen-settings-index.py --check >/dev/null && ok "índice de búsqueda de Ajustes al día" || bad "índice de Ajustes desactualizado: dev/gen-settings-index.py"
python3 dev/gen-pkgbuild.py --check >/dev/null && ok "PKGBUILD del AUR al día con packages.tsv" || bad "PKGBUILD desactualizado: dev/gen-pkgbuild.py"

# ── shellcheck ──
# Excluidos: SC2034 (variables que leen otros scripts con source), SC2155 (local x="$(…)": estilo), SC2088 (~ en
# textos para el usuario, no rutas), SC2010 (ls | grep sobre nombres que ponemos nosotros), SC2174 (mkdir -p -m: el
# modo solo hace falta en la última carpeta)
if command -v shellcheck >/dev/null; then
  out="$(shellcheck -S warning -e SC2034,SC2155,SC2088,SC2010,SC2174 -f gcc "${SH[@]}" 2>&1)"
  if [ -n "$out" ]; then bad "shellcheck:"; printf '%s\n' "$out" | sed 's|^|  |'; else ok "shellcheck"; fi
else note "sin shellcheck (ver la cabecera para instalarlo)"; fi

# ── pyflakes ──
# hf-sign importa Poppler y cairo solo para saber si están (se marcan con noqa, que pyflakes no entiende)
if command -v pyflakes >/dev/null; then
  out="$(pyflakes "${PY[@]}" 2>&1 | grep -vE "^scripts/hf-sign:[0-9]+:[0-9]+:? '(gi\.repository\.Poppler|cairo)' imported but unused")"
  if [ -n "$out" ]; then bad "pyflakes:"; printf '%s\n' "$out" | sed 's|^|  |'; else ok "pyflakes"; fi
else note "sin pyflakes (ver la cabecera para instalarlo)"; fi

exit "$fail"
