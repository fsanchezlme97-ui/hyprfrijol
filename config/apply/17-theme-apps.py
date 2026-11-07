# El tema del shell en las apps (Ajustes › Apariencia › «Aplicar el tema a las apps» = themeApps, con un interruptor
# por app) y los iconos Papirus con carpetas del color de acento (themeIcons, independiente). No devuelve Lua.
#
#  · kitty  (themeKitty)  include de ~/.local/state/hyprfrijol/kitty-colors.conf (esquema completo: 16 colores
#                         ANSI de la paleta, pestañas, selección) en un bloque al final de ~/.config/kitty/kitty.conf;
#                         en el mismo bloque, font_size de «Texto de la terminal» (termFontPx, aunque el tema esté apagado)
#  · Qt/KDE (themeQt)     esquema de color «HyprFrijol» (~/.local/share/color-schemes/HyprFrijol.colors) y sus
#                         [Colors:*] en ~/.config/kdeglobals: Dolphin, Kate, Okular… con QT_QPA_PLATFORMTHEME=kde
#                         (plasma-integration, lo fija env.lua). Con qt6ct instalado, también su paleta.
#                         La primera vez se guarda kdeglobals en ~/.local/state/hyprfrijol/kdeglobals.orig y al
#                         desactivarlo se restauran sus colores.
#  · btop   (themeBtop)   ~/.config/btop/themes/hyprfrijol.theme + color_theme en btop.conf (se recuerda el anterior)
#  · iconos (themeIcons, iconFolders = "acento" | "papirus" | color de papirus-folders)
#           papirus-folders necesita root (cambia /usr/share/icons); en su lugar se crea un tema de usuario
#           ~/.local/share/icons/Papirus-Frijol-{Dark,Light}-<color> que hereda de Papirus-Dark/-Light y solo contiene
#           enlaces de las carpetas al color elegido (el más cercano al acento). Se fija en gsettings, en
#           gtk-3.0/gtk-4.0 settings.ini, en kdeglobals [Icons] y en qt6ct.
# GTK/libadwaita: 16-gtk.py y 90-files.py (themeGtk).
# Recargas en vivo (kitty SIGUSR1, btop SIGUSR2, señales de KDE para paleta e iconos) solo con el HOME real:
# con un HOME de prueba (dev/try.sh) nunca se toca la sesión del usuario.
import colorsys, hashlib, json, os, pathlib, pwd, shutil, subprocess

HOME = pathlib.Path.home()
STATE = HOME / ".local/state/hyprfrijol"
MARK = "hyprfrijol (Ajustes › Apariencia)"
OLD_MARK = MARK.replace("hyprfrijol", "hypr-liquid")   # líneas que dejó el nombre anterior: se sustituyen
SCHEME = "HyprFrijol"
OLD_SCHEME = "HyprLiquid"   # nombre anterior (hypr-liquid): se borra al escribir el nuevo
KDE_SECTIONS = ("Colors:Button", "Colors:Complementary", "Colors:Header", "Colors:Header][Inactive",
                "Colors:Selection", "Colors:Tooltip", "Colors:View", "Colors:Window")
PAPIRUS_SIZES = ("22x22", "24x24", "32x32", "48x48", "64x64")
# Color principal de cada carpeta de papirus-folders (el frontal de folder-<color>.svg)
PAPIRUS_COLORS = {
    "black": "#4F4F4F", "blue": "#5294E2", "bluegrey": "#607D8B", "breeze": "#57B8EC", "brown": "#AE8E6C",
    "carmine": "#A30002", "cyan": "#00BCD4", "darkcyan": "#45ABB7", "deeporange": "#EB6637", "green": "#87B158",
    "grey": "#8E8E8E", "indigo": "#5C6BC0", "magenta": "#CA71DF", "nordic": "#81A1C1", "orange": "#EE923A",
    "palebrown": "#D1BFAE", "paleorange": "#EECA8F", "pink": "#F06292", "red": "#E25252", "teal": "#16A085",
    "violet": "#7E57C2", "white": "#E4E4E4", "yellow": "#F9BD30", "adwaita": "#93C0EA",
}


# ---------- utilidades ----------
def _rgb(h):
    h = h.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _mix(a, b, t):
    A, B = _rgb(a), _rgb(b)
    return "#%02X%02X%02X" % tuple(round(A[i] + (B[i] - A[i]) * t) for i in range(3))


def _kde(h):
    return "%d,%d,%d" % _rgb(h)


def _write(path, text):
    path = pathlib.Path(path)
    try:
        if path.exists() and path.read_text() == text:
            return False
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".hf-tmp")
        tmp.write_text(text)
        tmp.replace(path)
        return True
    except Exception:
        return False


def _real_home():
    try:
        return str(HOME) == pwd.getpwuid(os.getuid()).pw_dir
    except Exception:
        return False


def _gsettings_allowed():
    if os.environ.get("HF_GSETTINGS") == "1":
        return True
    if os.environ.get("HF_TRY") or os.environ.get("HF_NESTED"):
        return False
    return _real_home()


def _quiet(cmd):
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    except Exception:
        pass


# ---------- kitty ----------
# Bloque al final de ~/.config/kitty/kitty.conf (lo último gana sobre lo que el usuario tenga antes):
#   # >>> hyprfrijol (Ajustes › Apariencia) …
#   include ~/.local/state/hyprfrijol/kitty-colors.conf     (themeApps + themeKitty)
#   font_size 9.75                                         (termFontPx: «Texto de la terminal», px × 0,75)
#   # <<< hyprfrijol (Ajustes › Apariencia)
# kitty no admite comentarios al final de una línea: el antiguo «include …  # hyprfrijol (…)» hacía que kitty
# buscara un archivo con ese nombre entero y no cargara los colores. Se sustituye por el bloque.
# Con el tema activo, un «include» del tema de illogical-impulse (…/quickshell/user/generated/terminal/…) se
# comenta (con copia en ~/.local/state/hyprfrijol/kitty.conf.orig) y se vuelve a activar al apagarlo.
KITTY_BEGIN = "# >>> " + MARK + " · lo escribe hf-apply; no edites estas líneas"
KITTY_END = "# <<< " + MARK
KITTY_OFF = "# [hyprfrijol: desactivado] "
KITTY_FOREIGN = ("quickshell/user/generated/terminal/kitty-theme.conf",)


def kitty_font_pt(s):
    """font_size de kitty (pt) para termFontPx; None si no se toca (0, null o valor no válido)."""
    try:
        px = float(s.get("termFontPx", 13) or 0)
    except (TypeError, ValueError):
        return None
    if px <= 0:
        return None
    return f"{round(max(8.0, min(32.0, px)) * 0.75, 2):g}"


def apply_kitty(path, colors, font_pt):
    """Devuelve True si kitty.conf cambió."""
    path = pathlib.Path(path)
    try:
        text = path.read_text()
    except Exception:
        return False
    out, inside = [], False
    for l in text.splitlines():
        if l.startswith(KITTY_BEGIN[:12]) and MARK in l:
            inside = True
            continue
        if inside:
            if l.startswith(KITTY_END):
                inside = False
            continue
        if MARK in l or OLD_MARK in l:   # include con comentario al final (versiones anteriores)
            continue
        if any(f in l for f in KITTY_FOREIGN):
            s = l.strip()
            if colors and s.startswith("include"):
                l = KITTY_OFF + s
            elif not colors and s.startswith(KITTY_OFF):
                l = s[len(KITTY_OFF):]
        out.append(l)
    while out and not out[-1].strip():
        out.pop()
    block = []
    if colors:
        block.append(f"include {STATE / 'kitty-colors.conf'}")
    if font_pt:
        block.append(f"font_size {font_pt}")
    if block:
        out += [""] if out else []
        out += [KITTY_BEGIN, *block, KITTY_END]
    new = "\n".join(out) + "\n" if out else ""
    if new == text:
        return False
    orig = STATE / "kitty.conf.orig"
    if not orig.exists():
        try:
            STATE.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, orig)
        except Exception:
            pass
    return _write(path, new)


# ---------- INI conservando el resto del archivo (kdeglobals, settings.ini, qt6ct.conf) ----------
def _ini_read(path):
    """[(cabecera | None, [líneas])] en orden; cabecera sin corchetes exteriores ("Colors:Header][Inactive")."""
    try:
        text = pathlib.Path(path).read_text()
    except Exception:
        text = ""
    out = [[None, []]]
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            out.append([s[1:-1], []])
        else:
            out[-1][1].append(line)
    return out


def _ini_text(secs):
    parts = []
    for head, lines in secs:
        body = list(lines)
        while body and not body[-1].strip():
            body.pop()
        if head is None:
            if body:
                parts.append("\n".join(body))
            continue
        parts.append("\n".join(["[%s]" % head] + body))
    return "\n\n".join(parts) + "\n"


def _ini_section(secs, head):
    for s in secs:
        if s[0] == head:
            return s
    s = [head, []]
    secs.append(s)
    return s


def _ini_set(secs, head, key, value):
    """value None → borra la clave."""
    sec = _ini_section(secs, head)
    lines = [l for l in sec[1] if l.split("=", 1)[0].strip() != key]
    if value is not None:
        # tras la última clave (no tras líneas en blanco)
        i = len(lines)
        while i > 0 and not lines[i - 1].strip():
            i -= 1
        lines.insert(i, "%s=%s" % (key, value))
    sec[1] = lines


def _ini_get(secs, head, key):
    for h, lines in secs:
        if h == head:
            for l in lines:
                k, _, v = l.partition("=")
                if k.strip() == key:
                    return v.strip()
    return None


# ---------- Qt / KDE ----------
def kde_colors(c):
    """{sección: {clave: color}} del esquema de KDE a partir de la paleta."""
    LT = bool(c.get("light"))
    a = c.get("ansi") or []
    red = a[1] if len(a) == 16 else ("#B3261E" if LT else "#F2B8B5")
    green = a[2] if len(a) == 16 else "#4CAF50"
    yellow = a[3] if len(a) == 16 else "#E0A030"
    # Oscuro: ventana s1, vistas (lista de archivos) algo más oscuras, botones y cabeceras s3
    # Claro: vistas en la superficie más clara (s1), ventana y cabeceras un tono por debajo
    if LT:
        win, view, alt, btn, head = c["s3"], c["s1"], c["s3"], c["s1"], c["s4"]
    else:
        win, view, alt, btn, head = c["s1"], _mix(c["s1"], c["bg"], .55), c["s3"], c["s3"], c["s3"]

    def block(bg, bg_alt, fg, fg_in, extra=None):
        d = {"BackgroundNormal": bg, "BackgroundAlternate": bg_alt, "ForegroundNormal": fg,
             "ForegroundInactive": fg_in, "ForegroundActive": c["p"], "ForegroundLink": c["p"],
             "ForegroundVisited": c["ter"], "ForegroundNegative": red, "ForegroundNeutral": yellow,
             "ForegroundPositive": green, "DecorationFocus": c["p"], "DecorationHover": c["p"]}
        d.update(extra or {})
        return d

    return {
        "Colors:Window": block(win, alt, c["t"], c["tv"]),
        "Colors:View": block(view, _mix(view, c["s3"], .5), c["t"], c["tv"]),
        "Colors:Button": block(btn, c["s4"], c["t"], c["tv"]),
        "Colors:Header": block(head, win, c["t"], c["tv"]),
        "Colors:Header][Inactive": block(win, head, c["t"], c["tv"]),
        "Colors:Selection": block(c["p"], c["pc"], c["onP"], _mix(c["onP"], c["p"], .3),
                                  {"ForegroundActive": c["onP"], "ForegroundLink": c["onP"], "ForegroundVisited": c["onP"]}),
        "Colors:Tooltip": block(c["s4"], c["s3"], c["t"], c["tv"]),
        "Colors:Complementary": block(c["bg"] if not LT else "#1E1F22", c["s3"] if not LT else "#2A2B2F",
                                      c["t"] if not LT else "#E8E8E8", c["tv"] if not LT else "#B0B0B0"),
    }


def kde_wm(c):
    return {"activeBackground": c["s3"], "activeForeground": c["t"], "activeBlend": c["t"],
            "inactiveBackground": c["s1"], "inactiveForeground": c["tv"], "inactiveBlend": c["tv"]}


def apply_kde(c, on):
    """Devuelve True si kdeglobals cambió."""
    path = HOME / ".config/kdeglobals"
    orig = STATE / "kdeglobals.orig"
    secs = _ini_read(path)
    if on:
        cols = kde_colors(c)
        scheme = [["General", ["ColorScheme=%s" % SCHEME, "Name=HyprFrijol"]]]
        for head, kv in cols.items():
            scheme.append([head, ["%s=%s" % (k, _kde(v)) for k, v in kv.items()]])
        scheme.append(["WM", ["%s=%s" % (k, _kde(v)) for k, v in kde_wm(c).items()]])
        _write(HOME / ".local/share/color-schemes" / f"{SCHEME}.colors", _ini_text(scheme))
        (HOME / ".local/share/color-schemes" / f"{OLD_SCHEME}.colors").unlink(missing_ok=True)
        if path.exists() and not orig.exists() and _ini_get(secs, "General", "ColorScheme") not in (SCHEME, OLD_SCHEME):
            try:
                STATE.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, orig)
            except Exception:
                pass
        for head, kv in cols.items():
            _ini_section(secs, head)[1] = ["%s=%s" % (k, _kde(v)) for k, v in kv.items()]
        for k, v in kde_wm(c).items():
            _ini_set(secs, "WM", k, _kde(v))
        _ini_set(secs, "General", "ColorScheme", SCHEME)
        _ini_set(secs, "General", "ColorSchemeHash", None)
    else:
        if _ini_get(secs, "General", "ColorScheme") not in (SCHEME, OLD_SCHEME):
            return False
        old = _ini_read(orig) if orig.exists() else []
        for head in KDE_SECTIONS + ("WM",):
            prev = next((l for h, l in old if h == head), None)
            if prev is not None:
                _ini_section(secs, head)[1] = list(prev)
            else:
                secs[:] = [s for s in secs if s[0] != head]
        for k in ("ColorScheme", "ColorSchemeHash"):
            _ini_set(secs, "General", k, _ini_get(old, "General", k) if old else None)
    return _write(path, _ini_text(secs))


def apply_qt6ct(c, on, icon_theme):
    """Solo si qt6ct está instalado (con QT_QPA_PLATFORMTHEME=qt6ct manda su paleta, no kdeglobals)."""
    if not shutil.which("qt6ct"):
        return False
    conf = HOME / ".config/qt6ct/qt6ct.conf"
    changed = False
    if on:
        LT = bool(c.get("light"))
        win = c["s3"] if LT else c["s1"]
        base = c["s1"] if LT else _mix(c["s1"], c["bg"], .55)
        # orden de QPalette::ColorRole: WindowText Button Light Midlight Dark Mid Text BrightText ButtonText Base
        # Window Shadow Highlight HighlightedText Link LinkVisited AlternateBase NoRole ToolTipBase ToolTipText
        # PlaceholderText Accent
        roles = [c["t"], c["s3"], c["s4"], c["s4"], c["bg"], c["ov"], c["t"], "#FFFFFF", c["t"], base,
                 win, "#000000", c["p"], c["onP"], c["p"], c["ter"], c["s3"], "#000000", c["s4"], c["t"],
                 c["tv"], c["p"]]
        dis = [c["o"] if i in (0, 6, 8, 19) else r for i, r in enumerate(roles)]
        line = lambda l: ", ".join("#ff" + x.lstrip("#").lower() for x in l)
        scheme = "[ColorScheme]\nactive_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n" % (line(roles), line(dis), line(roles))
        path = HOME / ".config/qt6ct/colors/hyprfrijol.conf"
        changed |= _write(path, scheme)
        secs = _ini_read(conf)
        _ini_set(secs, "Appearance", "custom_palette", "true")
        _ini_set(secs, "Appearance", "color_scheme_path", str(path))
        if icon_theme:
            _ini_set(secs, "Appearance", "icon_theme", icon_theme)
        changed |= _write(conf, _ini_text(secs))
    elif conf.exists():
        secs = _ini_read(conf)
        if any(n in (_ini_get(secs, "Appearance", "color_scheme_path") or "") for n in ("hyprfrijol", "hypr-liquid")):   # hypr-liquid: nombre anterior
            _ini_set(secs, "Appearance", "custom_palette", "false")
            changed |= _write(conf, _ini_text(secs))
    return changed


# ---------- btop ----------
def btop_theme(c):
    a = c.get("ansi") or [c["p"]] * 16
    t = {
        "main_bg": c["s1"], "main_fg": c["t"], "title": c["t"], "hi_fg": c["p"],
        "selected_bg": c["pc"], "selected_fg": c["onPc"], "inactive_fg": c["o"], "graph_text": c["tv"],
        "meter_bg": c["s4"], "proc_misc": c["ter"], "cpu_box": c["ov"], "mem_box": c["ov"], "net_box": c["ov"],
        "proc_box": c["ov"], "div_line": c["ov"],
        "temp_start": a[2], "temp_mid": a[3], "temp_end": a[1],
        "cpu_start": c["p"], "cpu_mid": c["ter"], "cpu_end": a[1],
        "free_start": a[2], "free_mid": a[2], "free_end": a[10],
        "cached_start": a[4], "cached_mid": a[4], "cached_end": a[12],
        "available_start": a[3], "available_mid": a[3], "available_end": a[11],
        "used_start": a[1], "used_mid": a[1], "used_end": a[9],
        "download_start": c["pc"], "download_mid": c["p"], "download_end": a[12],
        "upload_start": _mix(c["ter"], c["s1"], .5), "upload_mid": c["ter"], "upload_end": a[13],
        "process_start": c["p"], "process_mid": c["ter"], "process_end": a[1],
    }
    return "# GENERADO por hyprfrijol (config/apply/17-theme-apps.py)\n" + \
        "".join('theme[%s]="%s"\n' % (k, v) for k, v in t.items())


def apply_btop(c, on):
    conf = HOME / ".config/btop/btop.conf"
    memo = STATE / "btop-theme.orig"
    if not shutil.which("btop") and not conf.exists():
        return False
    try:
        text = conf.read_text() if conf.exists() else ""
    except Exception:
        return False
    lines = text.splitlines()
    cur = next((l.split("=", 1)[1].strip().strip('"') for l in lines if l.split("=", 1)[0].strip() == "color_theme"), None)
    if on:
        changed = _write(HOME / ".config/btop/themes/hyprfrijol.theme", btop_theme(c))
        (HOME / ".config/btop/themes/hypr-liquid.theme").unlink(missing_ok=True)   # nombre anterior
        if cur != "hyprfrijol":
            try:
                STATE.mkdir(parents=True, exist_ok=True)
                if cur != "hypr-liquid":   # el tema con el nombre anterior también es nuestro: no es el «original»
                    memo.write_text(cur or "Default")
            except Exception:
                pass
            want = 'color_theme = "hyprfrijol"'
            lines = [want if l.split("=", 1)[0].strip() == "color_theme" else l for l in lines]
            if want not in lines:
                lines.append(want)
            changed |= _write(conf, "\n".join(lines) + "\n")
        return changed
    if cur in ("hyprfrijol", "hypr-liquid"):
        try:
            prev = memo.read_text().strip() or "Default"
        except Exception:
            prev = "Default"
        lines = ['color_theme = "%s"' % prev if l.split("=", 1)[0].strip() == "color_theme" else l for l in lines]
        return _write(conf, "\n".join(lines) + "\n")
    return False


# ---------- iconos ----------
def _lab(h):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in _rgb(h))
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    return 116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))


def folder_color(accent, available):
    """Color de papirus-folders más cercano al acento: en LCh, sobre todo por el tono (los acentos pastel tienen
    menos croma que las carpetas, así que croma y luminosidad pesan poco)."""
    import math
    r, g, b = (v / 255 for v in _rgb(accent))
    _, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.12:   # acento gris: carpetas neutras según su luminosidad
        for k in (("white" if l > 0.7 else "grey" if l > 0.4 else "black"), "grey"):
            if k in available:
                return k

    def lch(h):
        L, A, B = _lab(h)
        return L, math.hypot(A, B), math.degrees(math.atan2(B, A)) % 360
    L1, C1, H1 = lch(accent)
    best, bd = "blue", 1e18
    for k, v in PAPIRUS_COLORS.items():
        if k not in available or k in ("adwaita", "white", "black", "grey"):
            continue
        L2, C2, H2 = lch(v)
        dh = min(abs(H1 - H2), 360 - abs(H1 - H2))
        d = dh ** 2 + (0.35 * (C1 - C2)) ** 2 + (0.35 * (L1 - L2)) ** 2
        if d < bd:
            best, bd = k, d
    return best


def _icon_dirs():
    return [HOME / ".local/share/icons", HOME / ".icons", pathlib.Path("/usr/share/icons")]


def _find_theme(name):
    for d in _icon_dirs():
        if (d / name / "index.theme").exists():
            return d / name
    return None


def build_icon_theme(name, base_name, base_dir, color):
    """Tema de usuario que hereda de base y cambia solo las carpetas (como papirus-folders, sin root)."""
    out = HOME / ".local/share/icons" / name
    stamp = "%s %s %s v2" % (base_name, base_dir, color)
    try:
        if (out / ".hf-stamp").read_text() == stamp:
            return False
    except Exception:
        pass
    if out.exists():
        shutil.rmtree(out, ignore_errors=True)
    dirs = []
    for size in PAPIRUS_SIZES:
        src = (base_dir / size / "places").resolve()
        if not src.is_dir():
            continue
        dst = out / size / "places"
        dst.mkdir(parents=True, exist_ok=True)
        over = {}
        for pre in ("folder-" + color, "user-" + color):
            for f in src.glob(pre + "*.svg"):
                if f.is_symlink() or not (f.name == pre + ".svg" or f.name.startswith(pre + "-")):
                    continue
                generic = f.name.replace("-" + color, "", 1)
                over[generic] = f
        for generic, f in over.items():
            (dst / generic).symlink_to(f)
        # Alias (inode-directory → folder, folder-home → user-home…) que apuntan a una carpeta cambiada
        for f in src.iterdir():
            if f.name in over or not f.is_symlink():
                continue
            name_, seen = f.name, 0
            while seen < 6:
                try:
                    tgt = os.readlink(src / name_)
                except OSError:
                    break
                if "/" in tgt:
                    break
                name_ = tgt
                if name_ in over:
                    (dst / f.name).symlink_to(name_)
                    break
                seen += 1
        n = int(size.split("x")[0])
        dirs.append((size + "/places", n, 1))
        (out / (size + "@2x")).symlink_to(size)
        dirs.append((size + "@2x/places", n, 2))
    idx = ["[Icon Theme]", "Name=%s" % name, "Comment=Papirus con carpetas %s (hyprfrijol)" % color,
           "Inherits=%s,breeze-dark,hicolor" % base_name if "Dark" in base_name else "Inherits=%s,breeze,hicolor" % base_name,
           "Example=folder", "FollowsColorScheme=true", "Directories=" + ",".join(d[0] for d in dirs), ""]
    for d, n, sc in dirs:
        idx += ["[%s]" % d, "Context=Places", "Size=%d" % n] + (["Scale=2"] if sc == 2 else []) + ["Type=Fixed", ""]
    (out / "index.theme").write_text("\n".join(idx))
    (out / ".hf-stamp").write_text(stamp)
    return True


def apply_icons(s, c):
    """Nombre del tema de iconos fijado ('' si no se toca)."""
    if s.get("themeIcons", True) is False:
        return ""
    light = bool(c.get("light"))
    base_name = "Papirus-Light" if light else "Papirus-Dark"
    base_dir = _find_theme(base_name) or _find_theme("Papirus")
    if not base_dir:
        return ""
    if base_dir.name == "Papirus":
        base_name = "Papirus"
    mode = str(s.get("iconFolders", "acento") or "acento")
    if mode == "papirus":
        return base_name
    places = (base_dir / "48x48/places").resolve()
    available = {f.name[len("folder-"):-len("-documents.svg")] for f in places.glob("folder-*-documents.svg")}
    color = mode if mode in available else folder_color(c.get("accent") or c["p"], available)
    # El color va en el nombre: así cambia el valor de gsettings/kdeglobals y las apps recargan los iconos
    name = "Papirus-Frijol-%s-%s" % ("Light" if light else "Dark", color)
    try:
        build_icon_theme(name, base_name, base_dir, color)
        icons = HOME / ".local/share/icons"
        for old in [*icons.glob("Papirus-Frijol-*"), *icons.glob("Papirus-Liquid-*")]:   # Liquid: nombre anterior
            if old.name != name and ((old / ".hf-stamp").exists() or (old / ".hl-stamp").exists()):
                shutil.rmtree(old, ignore_errors=True)
    except Exception:
        return base_name
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        (STATE / "icon-folders").write_text(color + "\n")   # lo muestra Ajustes › Apariencia
    except Exception:
        pass
    return name


def set_icon_theme(name, qt):
    changed = False
    for d in ("gtk-3.0", "gtk-4.0"):
        p = HOME / ".config" / d / "settings.ini"
        secs = _ini_read(p)
        if _ini_get(secs, "Settings", "gtk-icon-theme-name") != name:
            _ini_set(secs, "Settings", "gtk-icon-theme-name", name)
            changed |= _write(p, _ini_text(secs))
    if qt:
        p = HOME / ".config/kdeglobals"
        secs = _ini_read(p)
        if _ini_get(secs, "Icons", "Theme") != name:
            _ini_set(secs, "Icons", "Theme", name)
            changed |= _write(p, _ini_text(secs))
    if shutil.which("gsettings") and _gsettings_allowed():
        try:
            cur = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
                                 capture_output=True, text=True, timeout=5).stdout.strip().strip("'")
            if cur != name:
                _quiet(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", name])
        except Exception:
            pass
    return changed


# ---------- entrada ----------
def hypr_lua(s, c):
    on = bool(s.get("themeApps"))
    want = lambda k: on and s.get(k, True) is not False
    STATE.mkdir(parents=True, exist_ok=True)
    memo_p = STATE / "theme-apps.json"
    try:
        memo = json.loads(memo_p.read_text())
    except Exception:
        memo = {}
    now = {}

    # kitty: bloque gestionado al final de kitty.conf (si kitty está o ya hay kitty.conf)
    kconf = HOME / ".config/kitty/kitty.conf"
    kitty = want("themeKitty")
    kpt = kitty_font_pt(s)
    if (kitty or kpt) and not kconf.exists() and shutil.which("kitty"):
        kconf.parent.mkdir(parents=True, exist_ok=True)
        kconf.write_text("")
    kitty_changed = apply_kitty(kconf, kitty, kpt) if kconf.exists() else False
    now["kitty"] = kitty

    qt = want("themeQt")
    kde_changed = apply_kde(c, qt)
    icon = ""
    try:
        icon = apply_icons(s, c)
    except Exception:
        pass
    if icon:
        kde_changed |= set_icon_theme(icon, True)
    apply_qt6ct(c, qt, icon)
    now["kde"] = hashlib.md5(json.dumps([qt, kde_colors(c) if qt else None]).encode()).hexdigest()
    now["icons"] = icon

    btop = want("themeBtop")
    apply_btop(c, btop)
    now["btop"] = hashlib.md5(btop_theme(c).encode()).hexdigest() if btop else ""

    try:
        memo_p.write_text(json.dumps(now))
    except Exception:
        pass

    # Recargas en vivo, solo en la sesión real
    if _real_home() and not os.environ.get("HF_TRY"):
        if kitty_changed or now["kitty"] != memo.get("kitty"):
            # SIGUSR1: cada kitty vuelve a leer kitty.conf (colores, fuente…). Solo los procesos del usuario.
            _quiet(["pkill", "-USR1", "-u", str(os.getuid()), "-x", "kitty"])
        if now["btop"] != memo.get("btop"):
            _quiet(["pkill", "-USR2", "-x", "btop"])
        if shutil.which("dbus-send"):
            if now["kde"] != memo.get("kde") or kde_changed:
                # KGlobalSettings::PaletteChanged (0): las apps de KDE releen kdeglobals
                _quiet(["dbus-send", "--session", "--type=signal", "/KGlobalSettings",
                        "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0"])
            if now["icons"] != memo.get("icons"):
                _quiet(["dbus-send", "--session", "--type=signal", "/KIconLoader",
                        "org.kde.KIconLoader.iconChanged", "int32:0"])
    return []
