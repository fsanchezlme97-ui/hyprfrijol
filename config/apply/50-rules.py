# Reglas de ventana: apps del shell (Ajustes, Herramientas, Tareas) y quitar efectos a juegos en pantalla completa.
def hypr_lua(s, c):
    out = [
        'hl.window_rule({ name = "hf-shell-apps", match = { class = "^(org.quickshell)$", title = "^(Ajustes|Herramientas|Tareas)$" }, float = true, center = true })',
    ]
    if s.get("gameNoFx", True):
        out.append('hl.window_rule({ name = "hf-fullscreen-nofx", match = { fullscreen = true }, no_blur = true, no_shadow = true, no_anim = true })')
    return out
