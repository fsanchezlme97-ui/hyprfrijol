#!/usr/bin/env bash
# dev/try.sh — prueba hyprfrijol en un Hyprland anidado y saca una captura a 1440×900 (tamaño del diseño).
#
#   dev/try.sh [opciones] [vista …]
#     vista            se abre con Shell.open(<vista>) antes de la captura (spotlight, ajustes, ia…)
#     -o FILE          captura (por defecto /tmp/hf-try/<vista|escritorio>.png)
#     -w SEG           espera antes de la captura (por defecto 9)
#     -c 'CMD'         comando extra dentro de la sesión antes de la captura (p. ej. notify-send …)
#     -k               no cerrar la sesión al terminar (imprime cómo conectarse)
#     -r WxH           resolución de la pantalla virtual (por defecto 1440x900, la del diseño)
#     -x 'CMD'         sonda: comando que corre en la sesión anidada (hyprctl, $QS ipc …) antes de la captura
#     -s 'k=v …'       ajustes temporales (hf-apply set) solo para esta prueba; se restauran al acabar
#     -S               modo seguro: arranca hf-session --safe (config/hypr/safe.lua, sin Quickshell)
#
# Para probar un módulo que aún no está en modules/Modules.qml:
#   HF_DEV_MODULES="modules/spotlight/Spotlight.qml,modules/x/Otro.qml" dev/try.sh spotlight
#
# Imprime los avisos/errores de Quickshell. Compara la captura con design/capturas/<Pantalla>.png
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
OUT=""; WAIT=9; EXTRA=""; KEEP=0; SETS=""; PROBE=""; RES="1440x900"; SAFE=""
while getopts "o:w:c:ks:x:r:S" o; do case $o in S) SAFE=--safe;; r) RES=$OPTARG;; o) OUT=$OPTARG;; w) WAIT=$OPTARG;; c) EXTRA=$OPTARG;; k) KEEP=1;; s) SETS=$OPTARG;; x) PROBE=$OPTARG;; *) exit 1;; esac; done
shift $((OPTIND-1))
VIEWS=("$@")
NAME="${VIEWS[0]:-escritorio}"
mkdir -p /tmp/hf-try
OUT="${OUT:-/tmp/hf-try/$NAME.png}"
LOG=$(mktemp /tmp/hf-try/log.XXXX)

SETTINGS="$HOME/.config/hyprfrijol/settings.json"
if [ -n "$SETS" ]; then
  BAK=$(mktemp /tmp/hf-try/settings.bak.XXXX); cp "$SETTINGS" "$BAK" 2>/dev/null || echo '{}' > "$BAK"
  # shellcheck disable=SC2086
  "$ROOT/scripts/hf-apply" set $SETS --no-reload >/dev/null
fi

export HF_TRY=1
# En TU sesión: la ventana anidada (clase aquamarine) va a un espacio especial oculto y sin robar el foco,
# para no interrumpir lo que estés haciendo. Verla:  hyprctl dispatch 'hl.dsp.workspace.toggle_special("hftry")'
hyprctl eval 'hl.window_rule({ name = "hf-try-hidden", match = { class = "^aquamarine$" }, workspace = "special:hftry silent", no_initial_focus = true })' >/dev/null 2>&1 || true
# Bus de sesión propio: notificaciones, polkit y bandeja van a la sesión de prueba, no a la tuya
dbus-run-session -- "$ROOT/scripts/hf-session" --nested $SAFE >"$LOG" 2>&1 &
PID=$!
cleanup() {
  if [ "$KEEP" = 0 ]; then
    # Bus D-Bus de la prueba: lo que activó (valent, portales…) sobrevive a dbus-run-session si no se cierra
    local hp bus q
    hp=$(jq -r .pid <<<"${I:-}" 2>/dev/null)
    bus=$(tr '\0' '\n' < "/proc/${hp:-0}/environ" 2>/dev/null | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
    on_bus() { { tr '\0' '\n' < "/proc/$1/environ"; } 2>/dev/null | grep -qxF "DBUS_SESSION_BUS_ADDRESS=$bus"; }
    # Los portales primero, con su Hyprland aún vivo: si este se va antes, xdg-desktop-portal-hyprland da
    # segfault al salir (cientos de volcados en /var/lib/systemd/coredump)
    if [ -n "$bus" ]; then
      for q in $(pgrep -u "$(id -u)" -f '^/usr/lib/xdg-desktop-portal'); do on_bus "$q" && kill "$q" 2>/dev/null; done
      sleep 0.3
    fi
    [ -n "${SIG:-}" ] && HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1
    sleep 1; kill "$PID" 2>/dev/null; sleep 0.5; kill -9 "$PID" 2>/dev/null
    [ -n "${SIG:-}" ] && rm -rf "${XDG_RUNTIME_DIR:-/tmp}/hf-webapp-$SIG"   # web apps de la prueba (hf-webapp con HF_NESTED)
    if [ -n "$bus" ]; then
      for q in $(pgrep -u "$(id -u)"); do
        on_bus "$q" && { kill "$q"; kill -CONT "$q"; } 2>/dev/null   # CONT: un mpvpaper pausado (SIGSTOP) no atiende TERM
      done
    fi
  fi
  if [ -n "$SETS" ]; then cp "$BAK" "$SETTINGS"; rm -f "$BAK"; "$ROOT/scripts/hf-apply" --no-reload >/dev/null; fi
}
trap cleanup EXIT

# Esperar a NUESTRA instancia (descendiente de $PID; puede haber otras pruebas a la vez)
is_ours() { local p=$1; while [ "$p" -gt 1 ] 2>/dev/null; do [ "$p" = "$PID" ] && return 0; p=$(awk '/^PPid:/{print $2}' /proc/$p/status 2>/dev/null || echo 0); done; return 1; }
I=""
for _ in $(seq 60); do
  while read -r line; do
    p=$(jq -r .pid <<<"$line"); is_ours "$p" && { I=$line; break; }
  done < <(hyprctl instances -j 2>/dev/null | jq -c '.[]')
  [ -n "$I" ] && break; sleep 0.5
done
[ -z "${I:-}" ] && { echo "No arrancó el Hyprland anidado"; cat "$LOG"; exit 1; }
SIG=$(jq -r .instance <<<"$I"); SOCK=$(jq -r .wl_socket <<<"$I")
export HYPRLAND_INSTANCE_SIGNATURE=$SIG
sleep 1.5
# Salida virtual de 1440×900 a escala 1 (como el diseño) y apagar la ventana anidada
hyprctl output create headless HF-TRY >/dev/null 2>&1
hyprctl eval 'hl.monitor({ output = "HF-TRY", mode = "'"$RES"'@60", position = "0x0", scale = 1 })' >/dev/null 2>&1
hyprctl eval 'hl.monitor({ output = "WAYLAND-1", disabled = true })' >/dev/null 2>&1
sleep 2.5
hyprctl dispatch 'hl.dsp.focus({ monitor = "HF-TRY" })' >/dev/null 2>&1
QS="qs -p $ROOT/config/quickshell"
in_session() { hyprctl dispatch "hl.dsp.exec_cmd(\"$1\")" >/dev/null; }
[ -n "$EXTRA" ] && { in_session "$EXTRA"; sleep 1; }
sleep "$WAIT"
for v in "${VIEWS[@]}"; do in_session "$QS ipc call shell open $v"; sleep 1.2; done
[ "${#VIEWS[@]}" -gt 0 ] && sleep 1
# -x: comando de diagnóstico que corre YA apuntando a la sesión anidada (nunca a la tuya)
if [ -n "$PROBE" ]; then
  echo "--- sonda ---"
  HPID=$(jq -r .pid <<<"$I")
  NBUS=$(tr '\0' '\n' < /proc/$HPID/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
  [ -n "$NBUS" ] || { echo "sin bus propio de la prueba; no ejecuto la sonda"; NBUS=none; }
  [ "$NBUS" = none ] || WAYLAND_DISPLAY=$SOCK DBUS_SESSION_BUS_ADDRESS=$NBUS QS="$QS" sh -c "$PROBE"
fi
WAYLAND_DISPLAY=$SOCK grim -o HF-TRY "$OUT" && echo "captura: $OUT"
if [ -n "$SAFE" ]; then   # modo seguro: no debe haber Quickshell en la sesión de prueba
  n=0; for q in $(pgrep -x qs; pgrep -x quickshell); do tr '\0' '\n' < /proc/$q/environ 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$SIG" && n=$((n+1)); done
  echo "--- modo seguro: Quickshell en la sesión de prueba: $n (debe ser 0) ---"
else
echo "--- quickshell (avisos y errores) ---"
WAYLAND_DISPLAY=$SOCK qs log -p "$ROOT/config/quickshell" 2>/dev/null | grep -E -A3 "WARN|ERROR|caused by" | grep -vE "notification server|Registration will be attempted|placeholder screen|does not correspond to a real screen" | sort | uniq -c | head -40
fi
if [ "$KEEP" = 1 ]; then
  echo "Sesión abierta: HYPRLAND_INSTANCE_SIGNATURE=$SIG WAYLAND_DISPLAY=$SOCK  (pid $PID)"
  trap - EXIT
fi
