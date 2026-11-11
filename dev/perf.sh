#!/usr/bin/env bash
# dev/perf.sh — consumo del shell en reposo, medido en un Hyprland anidado (dev/try.sh) con un HOME falso.
#
#   dev/perf.sh               reposo: 20 s tras asentarse
#   dev/perf.sh -t 40         ventana de medida en segundos
#   dev/perf.sh -v ajustes    además mide con esa vista abierta (spotlight, ajustes, vista…)
#
# Imprime CPU del hilo principal de Quickshell (JS/QML), de los hilos de render, de los procesos que lanza, y la
# memoria (RSS). Sirve para comparar antes y después de un cambio: la sesión anidada no recibe tu teclado ni tu ratón.
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T=20; VIEW=""
while getopts "t:v:" o; do case $o in t) T=$OPTARG;; v) VIEW=$OPTARG;; *) exit 1;; esac; done
TMP="$(mktemp -d "${TMPDIR:-/tmp}/hf-perf.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
FH="$TMP/home"
mkdir -p "$FH/.config" "$FH/.local/state" "$FH/.cache"
cp -rL "$HOME/.config/hyprfrijol" "$FH/.config/" 2>/dev/null || mkdir -p "$FH/.config/hyprfrijol"
cp -rL "$HOME/.local/state/hyprfrijol" "$FH/.local/state/" 2>/dev/null || true
[ -d "$HOME/.config/hypr" ] && cp -rL "$HOME/.config/hypr" "$FH/.config/" 2>/dev/null

cat > "$TMP/probe.sh" <<EOF
#!/bin/bash
q=""; for p in \$(pgrep -x qs); do tr '\0' '\n' < /proc/\$p/environ 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=\$HYPRLAND_INSTANCE_SIGNATURE" && q=\$p; done
[ -n "\$q" ] || { echo "sin Quickshell en la prueba"; exit 1; }
hz=\$(getconf CLK_TCK)
snap() {   # principal render resto hijos
  local m=0 r=0 o=0 t c n
  for t in /proc/\$q/task/*; do
    c=\$(awk '{print \$14+\$15}' \$t/stat 2>/dev/null) || continue; n=\$(cat \$t/comm 2>/dev/null)
    if [ "\$(basename \$t)" = "\$q" ]; then m=\$c; elif [ "\$n" = QSGRenderThread ]; then r=\$((r+c)); else o=\$((o+c)); fi
  done
  echo "\$m \$r \$o \$(awk '{print \$16+\$17}' /proc/\$q/stat)"
}
measure() {
  read -r m0 r0 o0 h0 < <(snap); sleep $T; read -r m1 r1 o1 h1 < <(snap)
  pc() { echo "scale=2; 100 * (\$1) / (\$hz * $T)" | bc; }
  printf '  %-10s principal %5s %%  render %5s %%  otros hilos %5s %%  procesos lanzados %5s %%   RSS %s MB\n' "\$1" \
    "\$(pc \$((m1-m0)))" "\$(pc \$((r1-r0)))" "\$(pc \$((o1-o0)))" "\$(pc \$((h1-h0)))" "\$((\$(awk '/VmRSS/{print \$2}' /proc/\$q/status) / 1024))"
}
measure reposo
if [ -n "$VIEW" ]; then \$QS ipc call shell open "$VIEW"; sleep 3; measure "$VIEW"; fi
EOF
chmod +x "$TMP/probe.sh"

echo "▸ Sesión anidada con HOME falso; medida de ${T} s tras asentarse (~$((T + 30)) s)…"
( unset HL_ROOT; export HF_ROOT="$ROOT" HOME="$FH"; "$ROOT/dev/try.sh" -w 20 -x "$TMP/probe.sh" -o "$TMP/perf.png" 2>&1 ) \
  | sed -n '/--- sonda ---/,/^captura:/p' | grep -vE '^(--- sonda ---|captura:)'
