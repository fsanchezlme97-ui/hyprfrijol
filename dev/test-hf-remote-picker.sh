#!/usr/bin/env bash
# dev/test-hf-remote-picker.sh — comprueba cuándo «hf-remote picker» aprueba solo (AnyDesk entrante reciente) y
# cuándo pasa la petición al selector de verdad. Con un HOME falso: no toca tu sesión ni tus ajustes.
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.anydesk" "$T/.config/hyprfrijol"
printf '#!/bin/sh\necho REAL "$@"\n' > "$T/real"; chmod +x "$T/real"
trace() { printf '   info %s       lsvc   main 1 1 28                      app.session - Connecting to current session 1.\n' "$(date -u -d "@$1" '+%F %T.000')" > "$T/.anydesk/anydesk.trace"; }
run() { env -i HOME="$T" PATH="/usr/bin:/bin" HF_REAL_PICKER="$T/real" HF_REMOTE_DRY_RUN=1 XDPH_WINDOW_SHARING_LIST="${W:-}" \
          XDPH_WORKSPACE_SHARING_LIST_V3="${WS:-}" "$ROOT/scripts/hf-remote" picker "$@" 2>/dev/null | grep -v '^# aviso'; }
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FALLO $1: «$2» ≠ «$3»"; fail=1; fi; }
now=$(date +%s)
trace $((now - 10));  check "consentimiento con AnyDesk reciente"     "$(run --remote-desktop)" "[AUTHORIZED]"
trace $((now - 600)); check "consentimiento con AnyDesk antiguo"      "$(run --remote-desktop)" "REAL --remote-desktop"
rm -f "$T/.anydesk/anydesk.trace"; check "consentimiento sin AnyDesk"   "$(run --remote-desktop)" "REAL --remote-desktop"
trace $((now - 10)); echo '{"remoteUnattended": false}' > "$T/.config/hyprfrijol/settings.json"
check "consentimiento con remoteUnattended=false" "$(run --remote-desktop)" "REAL --remote-desktop"
rm -f "$T/.config/hyprfrijol/settings.json"
W="0[HC>]kitty[HT>]x[HE>]" check "compartir con ventanas (Meet…) pregunta" "$(W="0[HC>]kitty[HT>]x[HE>]" run)" "REAL"
exit $fail
