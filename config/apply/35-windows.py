# Modo de ventanas (Ajustes › Escritorio y gestos › Modo de ventanas, atajo Super + Mayús + Espacio):
#   windowMode = "mosaico"        (por defecto) las ventanas se reparten la pantalla
#                "desplazamiento" columnas en una cinta (general:layout = scrolling, lo pone 30-layout.py)
#                "flotante"       escritorio clásico: todas las ventanas flotan, en todos los espacios
# El antiguo "mixto" (mosaico + un espacio flotante, "floatWorkspace") se trata como "mosaico".
# La colocación de las ventanas nuevas (tamaño cómodo, centradas y en cascada), el cambio en vivo de las
# ventanas abiertas, las excepciones por espacio y minimizar (espacio especial «minimized») los hace el shell
# (services/WinMode.qml).
#
# Apps que flotan al centro (Ajustes › Escritorio y gestos › Apps en ventana flotante):
#   floatApps     = ["org.gnome.Nautilus", "org.gnome.Loupe", …]  clases de ventana (sin distinguir mayúsculas)
#   floatAppsSize = 0.65  ancho respecto a la pantalla (el alto, un poco más: ver _size)
# Dos reglas: hf-float-apps (flotar + centrar + tamaño) y hf-float-apps-compact para las utilidades pequeñas
# (calculadoras, reproductores de audio mínimos), que flotan centradas con su propio tamaño. No tocan el PiP (va
# por título, 52-pip.py) ni los diálogos de rules.lua; services/WinMode.qml no las vuelve a mosaico al salir
# del modo flotante.
import re

# Barra de título del modo clásico (titleBars): la barra de grupo de Hyprland, con un grupo por ventana (WinMode.qml
# agrupa al abrirse las que no traen barra propia). Reserva su sitio encima de la ventana y la tapa la ventana que
# quede encima, sin plugins. El shell pinta encima de la de la ventana activa el icono, el título y los botones
# (modules/desktop/TitleBar.qml usa el mismo alto: Theme o WinMode.titleH). Sin grupos automáticos ni fusiones al
# arrastrar: cada ventana sigue suelta.
TITLE_H = 28


def _rgb(h):
    return "rgb(%s)" % str(h).lstrip("#")[-6:].lower()


def _groupbar(s, c):
    fam = str(s.get("fontFamily") or "Inter")
    if any(ch in fam for ch in "\"\n\\"):
        fam = "Inter"
    bg, fg = c.get("s1", "#202020"), c.get("tv", "#c0c0c0")
    return ('hl.config({ group = { auto_group = false, drag_into_group = 0, merge_groups_on_drag = false, '
            'merge_groups_on_groupbar = false, merge_floated_into_tiled_on_groupbar = false, groupbar = { '
            f'enabled = true, disable_when_only = false, render_titles = true, height = {TITLE_H}, '
            'indicator_height = 0, gradients = true, rounding = 10, gradient_rounding = 10, round_only_edges = true, '
            'gradient_round_only_edges = true, keep_upper_gap = false, gaps_in = 0, gaps_out = 0, '
            f'font_family = "{fam}", font_size = 11, text_padding = 12, text_color = "{_rgb(fg)}", '
            f'text_color_inactive = "{_rgb(fg)}", ["col.active"] = "{_rgb(bg)}", ["col.inactive"] = "{_rgb(bg)}", '
            f'["col.locked_active"] = "{_rgb(bg)}", ["col.locked_inactive"] = "{_rgb(bg)}" }} }} }})')

COMPACT = {"org.gnome.calculator", "gnome-calculator", "qalculate-gtk", "galculator", "org.gnome.decibels",
           "io.bassi.amberol", "org.gnome.zenity"}


def _num(v, d):
    try:
        return float(v)
    except (TypeError, ValueError):
        return d


def _classes(s):
    v = s.get("floatApps", [])
    if not isinstance(v, list):
        return []
    out = []
    for c in v:
        c = str(c).strip()
        # clase de ventana: letras, números y . _ - (nada que rompa la regex ni la cadena de Lua)
        if c and re.fullmatch(r"[A-Za-z0-9._-]{1,120}", c) and c.lower() not in (x.lower() for x in out):
            out.append(c)
    return out


def _rx(classes):
    alt = "|".join(re.escape(c).replace("\\", "\\\\") for c in classes)
    return f"(?i)^({alt})$"


def _size(s):
    w = min(0.9, max(0.4, _num(s.get("floatAppsSize"), 0.65)))
    h = min(0.9, w + 0.07)
    return w, h


def hypr_lua(s, c):
    out = []
    # Las ventanas en mosaico no se maximizan por su cuenta. En el modo flotante la regla no se pone: «float = false» se
    # evalúa al abrir la ventana, antes de que hf-float-all la haga flotar, y bloqueaba el botón de maximizar de las apps.
    if s.get("windowMode", "mosaico") == "flotante":
        out.append('hl.window_rule({ name = "hf-float-all", match = { class = ".*" }, float = true })')
    else:
        out.append('hl.window_rule({ name = "no-maximize", match = { float = false }, suppress_event = "maximize" })')
    # Modo clásico (general o por espacio): los diálogos modales (Abrir, Guardar…) no se maximizan; WinMode.opensMax()
    # mira esta etiqueta. Solo la ponen las apps que se declaran modales (GTK 4, Qt 6; GTK 3 no)
    out.append('hl.window_rule({ name = "hf-dialog", match = { modal = true }, tag = "+hf-dialog" })')
    out.append(_groupbar(s, c))
    cls = _classes(s)
    big = [x for x in cls if x.lower() not in COMPACT]
    small = [x for x in cls if x.lower() in COMPACT]
    if big:
        w, h = _size(s)
        out.append(f'hl.window_rule({{ name = "hf-float-apps", match = {{ class = "{_rx(big)}" }}, float = true, center = true, '
                   f'size = {{ "(monitor_w*{w:.2f})", "(monitor_h*{h:.2f})" }} }})')
    if small:
        out.append(f'hl.window_rule({{ name = "hf-float-apps-compact", match = {{ class = "{_rx(small)}" }}, float = true, center = true }})')
    return out
