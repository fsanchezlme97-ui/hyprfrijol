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

def _shadow(s, c, glass):
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
        if not glass:   # sólido: sombras más cortas
            rng = rng - 4
    else:
        rng, pw, off, a = (34, 2, "0 8", 0.13) if light else (38, 2, "0 8", 0.30)
        if not glass:   # sólido: sombras más cortas
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
    # Transparencia (estilo Math); sin el ajuste (settings.json de antes de 0.9.0), el estilo de antes (como hf-apply)
    t = s.get("transparencia")
    glass = bool(t) if t is not None else s.get("estilo") in ("skysoul", "aurora", "liquid", "tonal")
    # El desenfoque (el esmerilado del fondo oscurecido de la vista general) va siempre; los paneles sólidos son
    # opacos, así que solo se nota en los fondos translúcidos
    if not s.get("reduceTransparency") and not s.get("highContrast"):
        # Cristal: desenfoque suave que deja intuir las formas y los colores del fondo, algo de vibración para
        # que el color respire detrás del cristal y un poco oscurecido en modo oscuro para que el texto se lea
        # con tanta transparencia (los sólidos no lo necesitan)
        if q == "ahorro":
            deco.append("blur = { enabled = false }")
        else:
            # Moderado a propósito: con un radio muy grande el fondo se vuelve un gris uniforme y el cristal no se
            # nota; así se intuyen las formas y los colores de detrás
            size, passes = (7, 3) if q == "alta" else (6, 2)
            deco.append("blur = { size = %d, passes = %d, vibrancy = 0.35, vibrancy_darkness = 0.2, contrast = 0.95, brightness = %s, noise = 0.01 }"
                        % (size, passes, "1.05" if c.get("light") else "0.9"))
    deco.append(_shadow(s, c, glass))
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
