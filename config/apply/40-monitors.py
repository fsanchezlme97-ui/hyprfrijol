# Pantallas: Settings "monitors" = { "DP-1": { mode, position, scale, transform, vrr, hdr, mirror, disabled } } y uiScale.
# primaryMonitor: la pantalla principal (el espacio 1 se abre en ella).
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
    if prim and re.match(r"^[\w.-]+$", prim):
        out.append(f'hl.workspace_rule({{ workspace = "1", monitor = {_q(prim)}, default = true }})')
    ui = float(s.get("uiScale", 1) or 1)
    if ui != 1:
        # resto de pantallas (y las que se conecten): escala de la interfaz
        out.insert(0, f'hl.monitor({{ output = "", mode = "preferred", position = "auto", scale = {ui} }})')
    return out
