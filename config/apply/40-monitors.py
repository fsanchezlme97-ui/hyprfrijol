# Pantallas: Settings "monitors" = { "DP-1": { mode, position, scale, transform, vrr, hdr, mirror, disabled } } y uiScale.
# primaryMonitor: la pantalla principal (el espacio 1 se abre en ella).
# wsPerMonitor (por defecto true): cada pantalla con sus espacios (1-10, 11-20…; orden y reglas en frijol/workspaces.lua).
import re

def _q(v):
    return '"' + str(v).replace('"', '') + '"'

def hypr_lua(s, c):
    out = []
    mons = s.get("monitors") or {}
    for name, m in mons.items():
        if not re.match(r"^[\w.-]+$", name):
            continue
        if m.get("disabled"):
            out.append(f"hl.monitor({{ output = {_q(name)}, disabled = true }})")
            continue
        parts = [f"output = {_q(name)}", f"mode = {_q(m.get('mode') or 'preferred')}",
                 f"position = {_q(m.get('position') or 'auto')}", f"scale = {float(m.get('scale') or s.get('uiScale', 1))}"]
        try:
            tr = int(m.get("transform") or 0)
        except (TypeError, ValueError):
            tr = 0
        if 0 < tr <= 7:
            parts.append(f"transform = {tr}")
        if m.get("vrr"):
            parts.append("vrr = 1")
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
