# Espacios ocultos con nombre (Ajustes › Escritorio y gestos): hasta cuatro, cada uno con las apps que abren en él.
#   scratchpads = [{ "slot": 1, "name": "Música", "apps": ["spotify", "org.kde.elisa"] }, …]
# El del hueco n se muestra y esconde con Super + Fn; Super + Mayús + Fn le envía la ventana activa. Son espacios
# especiales «hfpad-n», aparte del oculto de Super + S, la consola y los minimizados. El hueco es fijo: quitar uno no
# cambia el atajo ni las ventanas de los demás (sin «slot», se reparten por orden; lo mismo que ui/Scratchpads.qml).
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


def slotted(pads):
    """[(hueco, espacio)]: cada uno su hueco si es válido y está libre; los demás, el primero libre."""
    pads = [p for p in pads if isinstance(p, dict)] if isinstance(pads, list) else []
    taken = {}
    for i, pad in enumerate(pads):
        slot = pad.get("slot")
        if type(slot) is int and 1 <= slot <= MAX and slot not in taken.values():
            taken[i] = slot
    free = [n for n in range(1, MAX + 1) if n not in taken.values()]
    for i in range(len(pads)):
        if i not in taken and free:
            taken[i] = free.pop(0)
    return sorted(((taken[i], pad) for i, pad in enumerate(pads) if i in taken), key=lambda p: p[0])


def hypr_lua(s, c):
    out = []
    for n, pad in slotted(s.get("scratchpads")):
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
