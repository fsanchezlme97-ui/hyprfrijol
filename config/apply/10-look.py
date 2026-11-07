# Apariencia y accesibilidad visual: esquinas, alto contraste, calidad del desenfoque, sombras y filtros de color.
import os, sys, pathlib, glob

def _rgba(h, a=1.0):
    h = h.lstrip("#")[-6:]
    return "rgba(%s%02x)" % (h.lower(), round(a * 255))

def _weak_gpu():
    """Equipo modesto: sin GPU con render (llvmpipe) o solo gráfica integrada Intel."""
    if not glob.glob("/dev/dri/renderD*"):
        return "ahorro"
    vendors = set()
    for v in glob.glob("/sys/class/drm/card[0-9]/device/vendor"):
        try:
            vendors.add(pathlib.Path(v).read_text().strip())
        except Exception:
            pass
    return "equilibrada" if vendors == {"0x8086"} else None

def _shadow(s, c, est):
    """Sombras de ventana (Ajustes › Apariencia › Ventanas › Sombras):
    suaves    amplias, difusas y con poca opacidad (por defecto); en claro, más tenues y teñidas del acento
    marcadas  más cortas y oscuras (elevación clara)
    ninguna   sin sombra
    Con «Resaltado: Brillo» la ventana activa lleva un halo del color de acento y las demás la sombra normal."""
    mode = s.get("shadows", "suaves")
    light = bool(c.get("light"))
    glow = s.get("activeBorder", "sutil") == "brillo"
    ink = c.get("p", "#000000")
    def tinted(a):   # negro con una pizca del acento: la sombra se ve menos «sucia» sobre fondos claros
        r1, g1, b1 = (int(ink.lstrip("#")[-6:][i:i + 2], 16) for i in (0, 2, 4))
        k = 0.18 if light else 0.06
        return "rgba(%02x%02x%02x%02x)" % (round(r1 * k), round(g1 * k), round(b1 * k), round(a * 255))
    if mode == "ninguna":
        if not glow:
            return "shadow = { enabled = false }"
        rng, pw, off, a = 18, 2, "0 0", 0.0
    elif mode == "marcadas":
        rng, pw, off, a = (16, 3, "0 4", 0.30) if light else (20, 3, "0 5", 0.55)
        if est == "flat":
            rng = rng - 4
    else:
        rng, pw, off, a = (34, 2, "0 8", 0.13) if light else (38, 2, "0 8", 0.30)
        if est == "flat":
            rng, off = rng - 10, "0 4"
    if glow:
        act = _rgba(ink, 0.30 if light else 0.26)
        return ('shadow = { enabled = true, range = %d, render_power = 2, offset = "0 0", color = "%s", color_inactive = "%s" }'
                % (max(rng, 22), act, tinted(a)))
    return ('shadow = { enabled = true, range = %d, render_power = %d, offset = "%s", color = "%s", color_inactive = "%s" }'
            % (rng, pw, off, tinted(a), tinted(a * 0.7)))

def hypr_lua(s, c):
    out = []
    deco = []
    if s.get("rounding") is not None and not s.get("_focus"):
        deco.append(f"rounding = {int(s['rounding'])}")
    q = s.get("blurQuality", "equilibrada")
    if s.get("blurAuto", True):
        cap = _weak_gpu()
        order = ["ahorro", "equilibrada", "alta"]
        if cap and order.index(cap) < order.index(q):
            q = cap
    est = s.get("estilo", "aurora")
    if est not in ("flat", "aurora", "mica", "suave"):
        est = "aurora"
    glass = est in ("aurora", "mica")
    if glass and not s.get("reduceTransparency") and not s.get("highContrast"):
        # Aurora: desenfoque amplio con algo de vibración y oscurecido para que el texto se lea.
        # Mica: más amplio y apagado (el fondo apenas se intuye detrás del material casi opaco)
        if q == "ahorro":
            deco.append("blur = { enabled = false }")
        elif est == "mica":
            deco.append("blur = { size = %d, passes = %d, vibrancy = 0.1, vibrancy_darkness = 0.0, contrast = 0.9, brightness = 0.8, noise = 0.02 }"
                        % ((14, 4) if q == "alta" else (12, 3)))
        elif q == "alta":
            deco.append("blur = { size = 10, passes = 4, vibrancy = 0.35, vibrancy_darkness = 0.25, contrast = 1.05, brightness = 0.85, noise = 0.014 }")
        else:
            deco.append("blur = { size = 8, passes = 3, vibrancy = 0.3, vibrancy_darkness = 0.2, contrast = 1.0, brightness = 0.88, noise = 0.014 }")
    deco.append(_shadow(s, c, est))
    filt = s.get("colorFilter", "ninguno")
    if filt and filt != "ninguno":
        for base in (os.environ.get("HF_ROOT", ""), str(pathlib.Path(sys.argv[0]).resolve().parent.parent)):
            p = pathlib.Path(base) / "config/apply/shaders" / f"{filt}.frag"
            if base and p.is_file():
                deco.append(f'screen_shader = "{p}"')
                break
    if deco:
        out.append("hl.config({ decoration = { " + ", ".join(deco) + " } })")
    if s.get("highContrast"):
        out.append("hl.config({ general = { border_size = 2, col = { active_border = \"%s\", inactive_border = \"%s\" } } })"
                   % (_rgba(c["t"]), _rgba(c["o"])))
    return out
