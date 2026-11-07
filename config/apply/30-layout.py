# Diseño de las ventanas según el modo (Ajustes › Escritorio › Modo de ventanas) y acople de las flotantes.
#   windowMode = "mosaico"        general:layout = "layout" (dwindle / master)
#                "desplazamiento" general:layout = "scrolling" (cinta de columnas nativa de Hyprland 0.57)
#                "flotante"       todas flotan (35-windows.py); debajo, el diseño del mosaico
# Compatibilidad: "layout" = "scrolling" con el modo mosaico (versiones anteriores) = desplazamiento.
# Desplazamiento: scrollColumnWidth (ancho de una columna nueva, fracción del área), scrollFocusFit
# ("ajustar": la columna enfocada se trae justo a la vista · "centrar": se centra), scrollOneFull (una sola
# columna ocupa todo el ancho). Los anchos de Super + ñ / ´ son los de explicit_column_widths.
WIDTHS = (0.333, 0.5, 0.667, 1.0)


def mode(s):
    wm = s.get("windowMode", "mosaico")
    if wm in ("flotante", "desplazamiento"):
        return wm
    return "desplazamiento" if s.get("layout") == "scrolling" else "mosaico"


def hypr_lua(s, c):
    lay = s.get("layout", "dwindle")
    if lay not in ("dwindle", "master"):
        lay = "dwindle"
    if mode(s) == "desplazamiento":
        lay = "scrolling"
    snap = "true" if s.get("snapEdges", True) else "false"
    try:
        w = float(s.get("scrollColumnWidth", 0.5))
    except (TypeError, ValueError):
        w = 0.5
    w = min(1.0, max(0.1, w))
    fit = 0 if s.get("scrollFocusFit", "ajustar") == "centrar" else 1
    one = "true" if s.get("scrollOneFull", True) else "false"
    widths = ", ".join(str(x) for x in WIDTHS)
    return [
        f'hl.config({{ general = {{ layout = "{lay}", snap = {{ enabled = {snap} }} }} }})',
        f'hl.config({{ scrolling = {{ column_width = {w:g}, focus_fit_method = {fit}, '
        f'fullscreen_on_one_column = {one}, explicit_column_widths = "{widths}" }} }})',
    ]
