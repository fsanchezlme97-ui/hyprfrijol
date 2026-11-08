# Apps GTK / libadwaita (Nautilus, Loupe, Papers, Editor de texto…) con el tema del shell, si themeApps está activado
# (Ajustes › Apariencia › «Aplicar a las apps»). No devuelve líneas: solo efectos fuera de Hyprland.
#  · ~/.local/state/hyprfrijol/gtk-adw.css: colores de libadwaita que gtk-colors.css (hf-apply) no define
#    (barra lateral, popovers, diálogos…), importado en ~/.config/gtk-4.0/gtk.css con una línea marcada
#  · gsettings org.gnome.desktop.interface: color-scheme (prefer-dark | default), accent-color (GNOME 47+:
#    blue teal green yellow orange red pink purple slate, el más cercano al color principal) y gtk-theme
#    adw-gtk3[-dark] si está instalado (apps GTK 3), font-name con la fuente del shell (fontFamily si sirve para texto) al tamaño de appFontPx
#    (Ajustes › Apariencia › Tipografía › «Texto de las apps», en px) y text-scaling-factor = 1
# Solo cambia lo que difiere. gsettings no se toca en sesiones de prueba (HF_TRY/HF_NESTED) ni con un HOME
# distinto del real (dconf escribiría en el del usuario de verdad); HF_GSETTINGS=1 lo fuerza.
import colorsys, os, pathlib, pwd, shutil, subprocess

HOME = pathlib.Path.home()
STATE = HOME / ".local/state/hyprfrijol"
MARK = "hyprfrijol (GTK/libadwaita)"
OLD_MARK = MARK.replace("hyprfrijol", "hypr-liquid")   # líneas que dejó el nombre anterior: se sustituyen
SCHEMA = "org.gnome.desktop.interface"


def _rgb(h):
    h = h.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def accent_name(hexcolor):
    r, g, b = _rgb(hexcolor)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.18 or l < 0.08 or l > 0.95:
        return "slate"
    deg = h * 360
    for limit, name in ((15, "red"), (40, "orange"), (65, "yellow"), (160, "green"), (195, "teal"),
                        (255, "blue"), (290, "purple"), (340, "pink"), (360, "red")):
        if deg < limit:
            return name
    return "blue"


def is_light(c):
    if "light" in c:
        return bool(c["light"])
    r, g, b = _rgb(c["bg"])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.5


def adw_css(c):
    return "\n".join([
        "/* GENERADO por config/apply/16-gtk.py · colores de libadwaita además de gtk-colors.css */",
        f"@define-color view_fg_color {c['t']};",
        f"@define-color headerbar_fg_color {c['t']};",
        f"@define-color headerbar_backdrop_color {c['s1']};",
        f"@define-color sidebar_bg_color {c['bg']};",
        f"@define-color sidebar_fg_color {c['t']};",
        f"@define-color sidebar_backdrop_color {c['bg']};",
        f"@define-color secondary_sidebar_bg_color {c['s1']};",
        f"@define-color secondary_sidebar_fg_color {c['t']};",
        f"@define-color popover_bg_color {c['s3']};",
        f"@define-color popover_fg_color {c['t']};",
        f"@define-color dialog_bg_color {c['s3']};",
        f"@define-color dialog_fg_color {c['t']};",
        f"@define-color card_fg_color {c['t']};",
        f"@define-color thumbnail_bg_color {c['s4']};",
        f"@define-color thumbnail_fg_color {c['t']};",
        f"@define-color accent_fg_color {c['onP']};",
        "",
    ])


def _line_file(path, line, want):
    path = pathlib.Path(path)
    try:
        text = path.read_text() if path.exists() else ""
    except Exception:
        return
    lines = [l for l in text.splitlines() if MARK not in l and OLD_MARK not in l]
    if want:
        lines.append(line)
    new = "\n".join(lines).strip("\n") + ("\n" if lines else "")
    if new != text and (want or MARK in text or OLD_MARK in text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(new)


def _gsettings_allowed():
    if os.environ.get("HF_GSETTINGS") == "1":
        return True
    if os.environ.get("HF_TRY") or os.environ.get("HF_NESTED"):
        return False
    try:
        return str(HOME) == pwd.getpwuid(os.getuid()).pw_dir
    except Exception:
        return False


def _gs(*args):
    try:
        return subprocess.run(["gsettings", *args], capture_output=True, text=True, timeout=5)
    except Exception:
        return None


def _gs_set(key, value):
    r = _gs("range", SCHEMA, key)
    if r is None or r.returncode != 0:
        return   # clave inexistente (GNOME < 47 no tiene accent-color)
    if r.stdout.startswith("enum") and f"'{value}'" not in r.stdout:
        return
    cur = _gs("get", SCHEMA, key)
    if cur is not None and cur.stdout.strip().strip("'") == value:
        return
    _gs("set", SCHEMA, key, value)


# Tamaño de la fuente de la interfaz de las apps GTK (y de Chrome/Chromium, que la toma de GTK), en píxeles:
# appFontPx, 12 por defecto como Windows (Segoe UI 9 pt a 96 ppp; macOS usa 13). GTK lo pide en puntos
# (px × 0,75). Con 11 pt, el valor de GNOME, pestañas, menús y barras de las apps se veían grandes.
# No depende de «Tamaño del texto» del shell (fontScale): text-scaling-factor se deja en 1.


def app_font_pt(s):
    try:
        px = max(9.0, min(24.0, float(s.get("appFontPx", 12))))
    except (TypeError, ValueError):
        px = 12.0
    return f"{round(px * 0.75, 2):g}"


def text_font(fam):
    """La familia elegida si existe y sirve para texto (cubre el español); si no, Inter o la sans del sistema.
    Una fuente de iconos (FontAwesome, Material Symbols…) como fuente de la interfaz deja las apps con letras
    de reserva de otro tamaño."""
    fam = str(fam or "").strip()
    ok = set()
    try:
        out = subprocess.run(["fc-list", ":lang=es", "family"], capture_output=True, text=True, timeout=5).stdout
        ok = {l.split(",")[0].strip() for l in out.splitlines() if l.strip()}
    except Exception:
        pass
    for f in (fam, "Inter"):
        if f and all(ch not in f for ch in "'\"\n") and (not ok or f in ok):
            return f
    return "Sans"


def _doto_font():
    """Chroma usa Doto (letra de puntos) en los títulos de las apps GTK: se enlaza la incluida en el repo a
    ~/.local/share/fonts para que fontconfig la encuentre."""
    src = pathlib.Path(__file__).resolve().parents[2] / "config/quickshell/assets/fonts/Doto.ttf"
    dst = HOME / ".local/share/fonts/hyprfrijol/Doto.ttf"
    try:
        if src.is_file() and not dst.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.symlink_to(src)
            if shutil.which("fc-cache"):
                subprocess.Popen(["fc-cache", str(dst.parent)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def hypr_lua(s, c):
    want = bool(s.get("themeApps")) and s.get("themeGtk", True) is not False
    css = STATE / "gtk-adw.css"
    if want:
        try:
            STATE.mkdir(parents=True, exist_ok=True)
            text = adw_css(c)
            if not css.exists() or css.read_text() != text:
                css.write_text(text)
        except Exception:
            pass
    if want and str(s.get("estilo")) in ("chroma", "mica"):
        _doto_font()
    _line_file(HOME / ".config/gtk-4.0/gtk.css", f'@import url("file://{css}"); /* {MARK} */', want)
    if want and shutil.which("gsettings") and _gsettings_allowed():
        light = is_light(c)
        _gs_set("color-scheme", "default" if light else "prefer-dark")
        _gs_set("accent-color", accent_name(c["p"]))
        _gs_set("font-name", f"{text_font(s.get('fontFamily'))} {app_font_pt(s)}")
        _gs_set("text-scaling-factor", "1.0")
        for theme in (("adw-gtk3" if light else "adw-gtk3-dark"),):
            if any((d / theme).is_dir() for d in (pathlib.Path("/usr/share/themes"), HOME / ".local/share/themes", HOME / ".themes")):
                _gs_set("gtk-theme", theme)
    return []
