# PiP (Ajustes › Panel lateral y PiP): regla de ventana con la esquina (pipCorner /
# pipFree) y el margen (pipMargin) de Ajustes, apartada de la barra. Así la ventana nace ya dentro de la zona
# libre de la pantalla; luego el shell (modules/pip/Pip.qml) la ajusta al píxel con lo que Hyprland reserva.
# Sin `size`: `move` calcula con window_w/window_h, y si la regla fijara 192×108 a una ventana que no baja de
# 300×225 (mínimo del navegador) la pondría fuera de la pantalla; el tamaño lo pide Pip.qml después.
# Sustituye a la regla "pip" de rules.lua (HF.rules.pip). Aunque el PiP del shell esté desactivado (pip = false)
# la regla se queda: el navegador lo abre flotante y dentro de la pantalla.
TITLE = r"^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture|[Pp]antalla[-\s]?en[-\s]?[Pp]antalla|[Ii]mage[mn]?[-\s]?(en|em|dentro de)[-\s]?[Ii]mage[mn]?)(.*)$"


def _num(v, d):
    try:
        return float(v)
    except (TypeError, ValueError):
        return d


def _bar_edges(s):
    """Margen de cada borde (izq, arr, der, aba) como Settings.barEdge del shell."""
    pos = s.get("barPos", "abajo")
    size = max(24, min(56, round(_num(s.get("barHeight"), 34) or 34)))
    floating = s.get("barMode", "fija") in ("flotante", "isla", "archipielago")
    vertical = pos in ("izquierda", "derecha")
    off = max(2, min(4, round(_num(s.get("gapsOut"), 4) or 0))) if floating else 0
    thick = size + 2 if vertical else size - 2 - (2 if floating else 0)
    behavior = s.get("barBehavior") or ("auto" if s.get("barAutoHide") is True else "siempre")
    edge = 4 if behavior == "auto" else off + thick + 4
    return {k: (edge if pos == k else 4) for k in ("izquierda", "arriba", "derecha", "abajo")}


def hypr_lua(s, c):
    m = max(0, round(_num(s.get("pipMargin"), 12)))
    e = _bar_edges(s)
    left, top, right, bottom = e["izquierda"] + m, e["arriba"] + m, e["derecha"] + m, e["abajo"] + m
    corner = s.get("pipCorner", "sup-der")
    free = s.get("pipFree")
    if corner == "libre" and isinstance(free, list) and len(free) == 2:
        fx = min(1.0, max(0.0, _num(free[0], 1.0)))
        fy = min(1.0, max(0.0, _num(free[1], 0.0)))
        # f·(pantalla − ventana): siempre dentro, sea cual sea el tamaño de la ventana
        x = f"(monitor_w*{fx:.4f}-window_w*{fx:.4f})"
        y = f"(monitor_h*{fy:.4f}-window_h*{fy:.4f})"
    else:
        x = (f"(monitor_w-window_w-{right})" if corner.endswith("der")
             else f"((monitor_w-window_w)/2)" if corner.endswith("centro") else f"{left}")
        y = f"(monitor_h-window_h-{bottom})" if corner.startswith("inf") else f"{top}"
    title = TITLE.replace("\\", "\\\\")
    return [
        "if HF.rules and HF.rules.pip then HF.rules.pip:set_enabled(false) end",
        f'hl.window_rule({{ name = "hf-pip", match = {{ title = "{title}" }}, float = true, pin = true, '
        f'keep_aspect_ratio = true, move = {{ "{x}", "{y}" }} }})',
    ]
