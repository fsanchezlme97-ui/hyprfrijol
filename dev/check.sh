#!/usr/bin/env bash
# dev/check.sh — prueba de humo antes de publicar: arranca hyprfrijol en un Hyprland anidado (dev/try.sh) con un HOME
# falso, abre todas las vistas y todas las secciones de Ajustes, y falla si Quickshell avisa de algún error de QML.
#
#   dev/check.sh            todas las vistas y secciones
#   dev/check.sh -v         además imprime todos los avisos (también los conocidos e inofensivos)
#
# HOME falso: copia (sin enlaces simbólicos: cp -L) de ~/.config/hyprfrijol y ~/.local/state/hyprfrijol, así la prueba
# nunca escribe en tus archivos de verdad. Sale con 0 si todo bien, 1 si hay errores (los imprime con la vista en que
# salieron).
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
VERBOSE=0; [ "${1:-}" = -v ] && VERBOSE=1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/hf-check.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
FH="$TMP/home"
mkdir -p "$FH/.config" "$FH/.local/state" "$FH/.cache"
cp -rL "$HOME/.config/hyprfrijol" "$FH/.config/" 2>/dev/null || mkdir -p "$FH/.config/hyprfrijol"
cp -rL "$HOME/.local/state/hyprfrijol" "$FH/.local/state/" 2>/dev/null || true
[ -d "$HOME/.config/hypr" ] && cp -rL "$HOME/.config/hypr" "$FH/.config/" 2>/dev/null

VIEWS="spotlight ajustes energia fondos actualizaciones vista widgets w-clima w-sistema w-impresora w-pomodoro bienvenida atajos musica w-dispositivos w-descargas captura color"
# Las secciones de Ajustes, de la lista de SettingsApp.qml (así una nueva entra sola)
SECTIONS="$(grep -oE '\{ key: "[a-z]+"' "$ROOT/config/quickshell/modules/settings/SettingsApp.qml" | sed -E 's/.*"([a-z]+)"/\1/' | tr '\n' ' ')"

cat > "$TMP/probe.sh" <<EOF
#!/bin/bash
Q="\${QS:-qs -p $ROOT/config/quickshell}"
OUT="$TMP/views.log"; : > "\$OUT"; N=0
mark() {
  local l; l="\$(\$Q log 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
  printf '%s\n' "\$l" | tail -n +\$((N+1)) | grep -E "WARN|ERROR|CRIT|Error" | sed "s|^|[\$1] |" >> "\$OUT"
  N=\$(printf '%s\n' "\$l" | wc -l)
}
sleep 4; mark inicio
for v in $VIEWS; do
  \$Q ipc call shell open "\$v"; sleep 1.6; \$Q ipc call shell close 2>/dev/null; sleep 0.4; mark "vista \$v"
done
for s in $SECTIONS; do \$Q ipc call settings open "\$s"; sleep 1.5; mark "ajustes \$s"; done
\$Q ipc call settings close; \$Q ipc call shell toggle ia; sleep 2; mark ia
echo fin >> "\$OUT"
EOF
chmod +x "$TMP/probe.sh"

echo "▸ Sesión anidada con HOME falso; abriendo $(wc -w <<<"$VIEWS") vistas y $(wc -w <<<"$SECTIONS") secciones de Ajustes (~2 min)…"
( unset HL_ROOT; export HF_ROOT="$ROOT" HOME="$FH"; "$ROOT/dev/try.sh" -w 2 -x "$TMP/probe.sh" -o "$TMP/check.png" >"$TMP/try.log" 2>&1 )
if ! grep -qx fin "$TMP/views.log" 2>/dev/null; then
  echo "✗ La prueba no llegó al final (¿arrancó la sesión anidada?):"; tail -20 "$TMP/try.log"; exit 1
fi

# Avisos conocidos e inofensivos: de la sesión anidada (polkit/portal ya registrados por tu sesión, sin bluez) y de Qt
KNOWN='qt\.qpa\.wayland\.textinput|PolicyKit1|PolkitAgent|polkit|register with host portal|org\.bluez|Could not load icon'
[ "$VERBOSE" = 1 ] && { echo "── todos los avisos ──"; grep -v '^fin$' "$TMP/views.log"; echo; }
BAD="$(grep -v '^fin$' "$TMP/views.log" | grep -vE "$KNOWN")"
if [ -n "$BAD" ]; then
  echo "✗ Avisos o errores nuevos:"; printf '%s\n' "$BAD" | cut -c1-300; exit 1
fi
echo "✓ Sin errores de QML en ninguna vista ni sección."
