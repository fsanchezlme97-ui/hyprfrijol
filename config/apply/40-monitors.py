# Pantallas: Settings "monitors" = { "DP-1": { mode, position, scale, transform, vrr (0…3), hdr, mirror, disabled } } y
# uiScale.
# primaryMonitor: la pantalla principal (el espacio 1 se abre en ella).
# wsPerMonitor (por defecto true): cada pantalla con sus espacios (1-10, 11-20…; orden y reglas en frijol/workspaces.lua).
import json, re

def _q(v):
    return json.dumps(str(v), ensure_ascii=False)   # escapa también «\» (un modo acabado en barra rompía settings.lua entero)

def _vrr(v):
    """0 apagada · 1 siempre · 2 solo a pantalla completa · 3 solo con juegos o vídeo. El «true» de antes es 1."""
    if v is True:
        return 1
    return v if isinstance(v, int) and v in (1, 2, 3) else 0


def _scale(v):
    try:
        return min(4.0, max(0.25, float(v)))
    except (TypeError, ValueError):
        return 1.0

def hypr_lua(s, c):
    out = []
    mons = s.get("monitors") or {}
    for name, m in mons.items():
        if not re.match(r"^[\w.-]+$", name) or not isinstance(m, dict):
            continue
        if m.get("disabled"):
            out.append(f"hl.monitor({{ output = {_q(name)}, disabled = true }})")
            continue
        parts = [f"output = {_q(name)}", f"mode = {_q(m.get('mode') or 'preferred')}",
                 f"position = {_q(m.get('position') or 'auto')}", f"scale = {_scale(m.get('scale') or s.get('uiScale', 1))}"]
        try:
            tr = int(m.get("transform") or 0)
        except (TypeError, ValueError):
            tr = 0
        if 0 < tr <= 7:
            parts.append(f"transform = {tr}")
        if "vrr" in m:   # apagada también se escribe: si no, seguiría valiendo misc:vrr
            parts.append(f"vrr = {_vrr(m['vrr'])}")
        if m.get("hdr"):
            parts += ['cm = "hdr"', "bitdepth = 10"]
        if m.get("mirror"):
            parts.append(f"mirror = {_q(m['mirror'])}")
        out.append("hl.monitor({ " + ", ".join(parts) + " })")
    prim = s.get("primaryMonitor") or ""
    if not (prim and re.match(r"^[\w.-]+$", prim)):
        prim = ""
    # Espacios por pantalla: el orden (y sus reglas) lo calcula frijol/workspaces.lua con las pantallas conectadas
    # de verdad (una principal guardada que ya no está no se queda con el 1-10); aquí solo los datos
    if s.get("wsPerMonitor", True) is not False:
        out.append("HF.wsPerMonitor = true")
    if prim:
        out.append(f"HF.wsPrimary = {_q(prim)}")
    known = sorted(n for n in mons if n != prim and re.match(r"^[\w.-]+$", n))
    out.append("HF.wsKnown = { " + ", ".join(_q(n) for n in known) + " }")
    # Apps que abren en la pantalla secundaria (secondaryApps, clases de ventana): la regla la pone workspaces.lua,
    # que sabe qué pantalla es la secundaria en cada momento
    apps = [c for c in (s.get("secondaryApps") or []) if isinstance(c, str) and re.fullmatch(r"[A-Za-z0-9._-]{1,120}", c)]
    if apps:
        alt = "|".join(re.escape(c).replace("\\", "\\\\") for c in apps)
        out.append(f'HF.secondaryApps = "(?i)^({alt})$"')
    ui = float(s.get("uiScale", 1) or 1)
    if ui != 1:
        # resto de pantallas (y las que se conecten): escala de la interfaz
        out.insert(0, f'hl.monitor({{ output = "", mode = "preferred", position = "auto", scale = {ui} }})')
    return out
