# hyprfrijol — menú «HyprFrijol» en el clic derecho de Nautilus (extensión de nautilus-python).
# La instala `hf-apps extension` (y install.sh con las apps de serie) como enlace en
# ~/.local/share/nautilus-python/extensions/hyprfrijol.py. Reinicia Nautilus para verla: nautilus -q
#
# Solo muestra el menú: el trabajo lo hace scripts/hf-fileact (la misma orden sirve en la terminal y para la IA).
#   Preguntar a la IA · Firmar PDF · Extraer texto (OCR) · Convertir… (submenú) · Poner de fondo
import importlib.machinery, importlib.util, os, shutil, subprocess
from urllib.parse import unquote, urlparse

try:
    import gi
    gi.require_version("Nautilus", "4.0")
    from gi.repository import GObject, Nautilus
except (ImportError, ValueError):   # fuera de Nautilus (pruebas): clases mínimas
    GObject = Nautilus = None


def _fileact_path():
    here = os.path.dirname(os.path.realpath(__file__))
    for p in (os.path.join(here, "..", "..", "scripts", "hf-fileact"), shutil.which("hf-fileact") or "",
              os.path.expanduser("~/.local/bin/hf-fileact")):
        if p and os.path.isfile(p):
            return os.path.realpath(p)
    return ""


FILEACT = _fileact_path()


def _load_fileact():
    """Importa hf-fileact como módulo para decidir qué acciones salen (sin lanzar un proceso en cada clic)."""
    if not FILEACT:
        return None
    try:
        loader = importlib.machinery.SourceFileLoader("hf_fileact", FILEACT)
        spec = importlib.util.spec_from_loader("hf_fileact", loader)
        mod = importlib.util.module_from_spec(spec)
        loader.exec_module(mod)
        return mod
    except Exception:
        return None


FA = _load_fileact()


def paths_of(files):
    out = []
    for f in files:
        uri = f.get_uri() if hasattr(f, "get_uri") else str(f)
        u = urlparse(uri)
        if u.scheme != "file":
            return []   # solo archivos locales (no smb://, trash://…)
        out.append(unquote(u.path))
    return out


def command(action, paths, fmt=None):
    """La orden que se ejecuta para cada entrada del menú."""
    return [FILEACT, action] + ([fmt] if fmt else []) + list(paths)


def launch(cmd):
    subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def entries(paths):
    """[(clave, etiqueta, orden)] y conversiones [(fmt, etiqueta, orden)] para estos archivos."""
    if not paths or FA is None or any(os.path.isdir(p) for p in paths):
        return [], []
    a = FA.actions(paths)
    items = []
    if a["ai"]: items.append(("ai", "Preguntar a la IA", command("ai", paths)))
    if a["sign"]: items.append(("sign", "Firmar PDF" if a["kinds"][0] == "pdf" else "Firmar (imagen)", command("sign", paths)))
    if a["ocr"]: items.append(("ocr", "Extraer texto (OCR)", command("ocr", paths)))
    conv = [(c["fmt"], c["label"], command("convert", paths, c["fmt"])) for c in a["convert"]]
    if a["wallpaper"]: items.append(("wallpaper", "Poner de fondo", command("wallpaper", paths)))
    return items, conv


if Nautilus is not None:
    class HyprFrijolMenu(GObject.GObject, Nautilus.MenuProvider):
        def _item(self, name, label, cmd=None):
            it = Nautilus.MenuItem(name="HyprFrijol::" + name, label=label)
            if cmd:
                it.connect("activate", lambda *_a: launch(cmd))
            return it

        def get_file_items(self, *args):
            files = args[-1]   # Nautilus 4: (files) · antiguas: (window, files)
            items, conv = entries(paths_of(files))
            if not items and not conv:
                return []
            top = self._item("root", "HyprFrijol")
            sub = Nautilus.Menu()
            top.set_submenu(sub)
            for key, label, cmd in items:
                if key == "wallpaper" and conv:   # «Convertir…» antes de «Poner de fondo»
                    sub.append_item(self._convert_menu(conv))
                    conv = []
                sub.append_item(self._item(key, label, cmd))
            if conv:
                sub.append_item(self._convert_menu(conv))
            return [top]

        def _convert_menu(self, conv):
            it = self._item("convert", "Convertir…")
            m = Nautilus.Menu()
            it.set_submenu(m)
            for fmt, label, cmd in conv:
                m.append_item(self._item("convert-" + fmt, label, cmd))
            return it

        def get_background_items(self, *args):
            return []
