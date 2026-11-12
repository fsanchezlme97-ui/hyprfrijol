# Efectos fuera de Hyprland (no devuelve líneas):
#  · reduceMotion → ~/.local/state/hyprfrijol/reduce-motion (lo lee hf-wallpaper)
#  · themeApps    → importa los colores en GTK 3/4 (themeGtk; línea marcada, se quita al desactivarlo)
#  · bigCursor    → XCURSOR_SIZE/HYPRCURSOR_SIZE (hl.env) — devuelve líneas
import pathlib

HOME = pathlib.Path.home()
STATE = HOME / ".local/state/hyprfrijol"
MARK = "hyprfrijol (Ajustes › Apariencia)"
OLD_MARK = MARK.replace("hyprfrijol", "hypr-liquid")   # líneas que dejó el nombre anterior: se sustituyen

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

ROOT = pathlib.Path(__file__).resolve().parents[2]

def _firmar_desktop():
    """Lanzador «Firmar documentos» en el menú de apps y en «Abrir con» de los PDF."""
    text = (
        "[Desktop Entry]\nType=Application\nName=Firmar documentos\n"
        "Comment=Firma PDF e imágenes con tu firma (hyprfrijol)\n"
        f"Exec={ROOT}/scripts/hf-firmar %f\n"
        "Icon=application-pkcs7-signature\nTerminal=false\nCategories=Office;\n"
        "MimeType=application/pdf;image/png;image/jpeg;\nKeywords=firma;firmar;pdf;signature;\n"
    )
    path = HOME / ".local/share/applications/hf-firmar.desktop"
    try:
        if not path.exists() or path.read_text() != text:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        (path.parent / "hl-firmar.desktop").unlink(missing_ok=True)   # nombre anterior (hypr-liquid)
    except Exception:
        pass

def _tareas_desktop():
    """Lanzador de la app «Tareas» (menú de apps y Spotlight)."""
    text = (
        "[Desktop Entry]\nType=Application\nName=Tareas\n"
        "Comment=Tu lista de pendientes con fecha (hyprfrijol)\n"
        f"Exec={ROOT}/scripts/hf-tareas\n"
        "Icon=checkbox-checked-symbolic\nTerminal=false\nCategories=Office;Utility;\n"
        "Keywords=tareas;pendientes;todo;lista;recordatorio;tasks;\n"
    )
    path = HOME / ".local/share/applications/hf-tareas.desktop"
    try:
        if not path.exists() or path.read_text() != text:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
    except Exception:
        pass

def _view_desktops():
    """Lanzadores de las apps sueltas que abren una vista del shell (modules/apps): menú de apps y Spotlight."""
    qs = f'qs -p "{ROOT}/config/quickshell" ipc call'      # entre comillas: la carpeta puede llevar espacios
    apps = [
        ("hf-remoto", "Conexiones remotas", "Escritorios de otros equipos (RDP, VNC, SSH)", "remoto", "preferences-desktop-remote-desktop",
         "Network;RemoteAccess;", "remoto;rdp;vnc;ssh;remmina;escritorio remoto;conexión;windows;"),
        ("hf-maquinas", "Máquinas virtuales", "Tus máquinas virtuales y contenedores", "maquinas", "computer",
         "System;Emulator;", "máquinas virtuales;vm;qemu;kvm;libvirt;virsh;distrobox;contenedor;podman;"),
        ("hf-impresion", "Cola de impresión", "Trabajos esperando para imprimirse", "impresion", "printer",
         "System;Printing;", "imprimir;cola;impresora;trabajos;cups;cancelar;"),
        ("hf-restauracion", "Puntos de restauración", "Instantáneas del sistema con snapper", "restauracion", "document-revert",
         "System;", "restaurar;snapper;snapshot;instantánea;btrfs;punto de restauración;volver atrás;"),
    ]
    for fid, name, comment, view, icon, cats, kw in apps:
        text = (f"[Desktop Entry]\nType=Application\nName={name}\nComment={comment} (hyprfrijol)\n"
                f"Exec={qs} {view} open\nIcon={icon}\nTerminal=false\nCategories={cats}\nKeywords={kw}\n")
        path = HOME / f".local/share/applications/{fid}.desktop"
        try:
            if not path.exists() or path.read_text() != text:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
        except Exception:
            pass

def hypr_lua(s, c):
    _firmar_desktop()
    _tareas_desktop()
    _view_desktops()
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        rm = STATE / "reduce-motion"
        if s.get("reduceMotion"):
            rm.touch()
        elif rm.exists():
            rm.unlink()
    except Exception:
        pass
    on = bool(s.get("themeApps"))
    css = STATE / "gtk-colors.css"
    gtk = on and s.get("themeGtk", True) is not False
    for d in ("gtk-3.0", "gtk-4.0"):
        _line_file(HOME / ".config" / d / "gtk.css", f'@import url("file://{css}"); /* {MARK} */', gtk)
    # kitty, Qt/KDE, btop e iconos: 17-theme-apps.py
    size = 48 if s.get("bigCursor") else 24
    return [f'hl.env("XCURSOR_SIZE", "{size}")', f'hl.env("HYPRCURSOR_SIZE", "{size}")'] if size != 24 else []
