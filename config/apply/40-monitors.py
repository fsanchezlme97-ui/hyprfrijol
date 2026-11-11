# Pantallas: Settings "monitors" = { "DP-1": { mode, position, scale, transform, vrr, hdr, mirror, disabled } } y uiScale.
# primaryMonitor: la pantalla principal (el espacio 1 se abre en ella).
# wsPerMonitor (por defecto true): cada pantalla con sus espacios (1-10, 11-20… en el orden de HF.wsGroups).
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
    if s.get("wsPerMonitor", True) is not False:
        # Espacios por pantalla (binds.lua: HF.wsBase; WsLabel.qml): la principal del 1 al 10, la siguiente del
        # 11 al 20… (orden: la principal y luego las demás por nombre; las desconectadas guardan su sitio)
        groups = ([prim] if prim else []) + sorted(n for n in mons if n != prim and re.match(r"^[\w.-]+$", n))
        out.append("HF.wsPerMonitor = true")
        out.append("HF.wsGroups = { " + ", ".join(_q(n) for n in groups) + " }")
        for k, name in enumerate(groups):
            for i in range(1, 11):
                d = ", default = true" if i == 1 else ""
                out.append(f'hl.workspace_rule({{ workspace = "{k * 10 + i}", monitor = {_q(name)}{d} }})')
    elif prim:
        out.append(f'hl.workspace_rule({{ workspace = "1", monitor = {_q(prim)}, default = true }})')
    ui = float(s.get("uiScale", 1) or 1)
    if ui != 1:
        # resto de pantallas (y las que se conecten): escala de la interfaz
        out.insert(0, f'hl.monitor({{ output = "", mode = "preferred", position = "auto", scale = {ui} }})')
    return out
