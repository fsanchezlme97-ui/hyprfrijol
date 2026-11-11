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
    if s.get("windowMode", "mosaico") == "flotante":
        out.append('hl.window_rule({ name = "hf-float-all", match = { class = ".*" }, float = true })')
    else:
        # En mosaico las apps no maximizan por su cuenta; en flotante su botón de maximizar sí funciona
        out.append('hl.window_rule({ name = "no-maximize", match = { class = ".*" }, suppress_event = "maximize" })')
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
