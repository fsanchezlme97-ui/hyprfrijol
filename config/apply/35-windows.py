# Modo de ventanas (Ajustes › Escritorio y gestos › Modo de ventanas, atajo Super + Mayús + Espacio):
#   windowMode = "mosaico"        (por defecto) las ventanas se reparten la pantalla
#                "desplazamiento" columnas en una cinta (general:layout = scrolling, lo pone 30-layout.py)
#                "flotante"       escritorio clásico: todas las ventanas flotan, en todos los espacios
# El antiguo "mixto" (mosaico + un espacio flotante, "floatWorkspace") se trata como "mosaico".
# La colocación de las ventanas nuevas (tamaño cómodo, centradas y en cascada), el cambio en vivo de las
# ventanas abiertas, las excepciones por espacio y minimizar (espacio especial «minimized») los hace el shell
# (services/WinMode.qml).
def hypr_lua(s, c):
    if s.get("windowMode", "mosaico") == "flotante":
        return ['hl.window_rule({ name = "hf-float-all", match = { class = ".*" }, float = true })']
    return []
