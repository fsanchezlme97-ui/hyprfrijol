# Espacios ocultos con nombre (Ajustes › Escritorio y gestos): hasta cuatro, cada uno con las apps que abren en él.
#   scratchpads = [{ "name": "Música", "apps": ["spotify", "org.kde.elisa"] }, …]
# El n-ésimo se muestra y esconde con Super + Fn; Super + Mayús + Fn le envía la ventana activa. Son espacios
# especiales «hfpad-n», aparte del oculto de Super + S, la consola y los minimizados.
import json
import re

MAX = 4


def _classes(apps):
    out = []
    for c in apps if isinstance(apps, list) else []:
        c = str(c).strip()
        if re.fullmatch(r"[A-Za-z0-9._-]{1,120}", c) and c not in out:
            out.append(c)
    return out


def hypr_lua(s, c):
    pads = s.get("scratchpads")
    out = []
    for n, pad in enumerate(pads[:MAX] if isinstance(pads, list) else [], 1):
        if not isinstance(pad, dict):
            continue
        name = " ".join(str(pad.get("name") or "").split())[:40] or f"Espacio {n}"
        ws = f"special:hfpad-{n}"
        title = json.dumps(f"Espacio oculto: {name}", ensure_ascii=False)
        send = json.dumps(f"Enviar al espacio oculto: {name}", ensure_ascii=False)
        out.append(f'hl.bind("SUPER + F{n}", hl.dsp.workspace.toggle_special("hfpad-{n}"), {{ description = {title} }})')
        out.append(f'hl.bind("SUPER + SHIFT + F{n}", hl.dsp.window.move({{ workspace = "{ws}", follow = false }}), '
                   f'{{ description = {send} }})')
        apps = _classes(pad.get("apps"))
        if apps:
            alt = "|".join(re.escape(a).replace("\\", "\\\\") for a in apps)
            out.append(f'hl.window_rule({{ name = "hf-pad-{n}", match = {{ class = "(?i)^({alt})$" }}, '
                       f'workspace = "{ws} silent" }})')
    return out
