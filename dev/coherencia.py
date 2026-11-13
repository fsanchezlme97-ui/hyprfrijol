#!/usr/bin/env python3
"""dev/coherencia.py — dos comprobaciones de dev/lint.sh:
  · cada clave de ajustes que usa el shell tiene valor por defecto en config/defaults/settings.json (si no, cada
    sitio inventa el suyo);
  · cada programa que el código busca (command -v X, shutil.which("X")) está en la columna «órdenes» de
    install/packages.tsv, salvo los del sistema y las alternativas que no instalamos nosotros (SISTEMA);
  · cada .qml que usa un singleton (Time., Settings., Battery.…) importa su carpeta: si no, falla solo al usarse
    («ReferenceError: Time is not defined») y dev/check.sh no lo ve."""
import json, pathlib, re, sys
root = pathlib.Path(__file__).resolve().parent.parent
fail = 0

defaults = json.loads((root / "config/defaults/settings.json").read_text())
used = {}
for p in (root / "config/quickshell").rglob("*"):
    if p.suffix in (".qml", ".js"):
        t = p.read_text()
        for rx in (r'Settings\.(?:get|set|toggle)\(\s*"([A-Za-z0-9_]+)"', r'SwRow\s*\{[^}\n]*\bkey:\s*"([A-Za-z0-9_]+)"'):
            for m in re.finditer(rx, t):
                used.setdefault(m.group(1), str(p.relative_to(root)))
miss = sorted(k for k in used if k not in defaults)
if miss:
    fail = 1
    print("Claves de ajustes sin valor por defecto (config/defaults/settings.json):")
    for k in miss:
        print(f"  {k}  ({used[k]})")

# del sistema base, gestores de paquetes y apps alternativas que solo se usan si ya están
SISTEMA = {"sudo", "doas", "logger", "dbus-send", "fc-list", "systemd-inhibit", "pacman", "paru", "yay", "dnf", "rpm",
           "dpkg", "dpkg-query", "uv", "nvidia-smi", "paplay", "pandoc", "spotify", "claude", "claude-desktop",
           "claude-desktop-bin", "forticlient", "globalprotect", "kdeconnect-cli",
           "localectl", "locale-gen"}   # systemd y glibc; hf-perfil comprueba que estén
known = set()
for line in (root / "install/packages.tsv").read_text().splitlines():
    c = line.split("\t")
    if not line.startswith("#") and len(c) >= 10:
        known |= {x.strip() for x in c[9].split(",") if x.strip()}
files = [p for p in (root / "scripts").iterdir() if p.is_file()] + list((root / "config").rglob("*.qml")) \
    + list((root / "config").rglob("*.py")) + [root / "install.sh"]
progs = {}
for p in files:
    try:
        t = p.read_text()
    except (UnicodeDecodeError, OSError):
        continue
    for rx in (r'command -v ([a-z][\w.+-]*)', r'\bwhich\(\s*"([a-z][\w.+-]*)"'):
        for m in re.finditer(rx, t):
            progs.setdefault(m.group(1), p.name)
miss = sorted(k for k in progs if k not in known | SISTEMA and not k.startswith("hf-"))
if miss:
    fail = 1
    print("Programas que usa el código y no están en install/packages.tsv (o en SISTEMA de dev/coherencia.py):")
    for k in miss:
        print(f"  {k}  ({progs[k]})")
Q = root / "config/quickshell"
singles = {d: {p.stem for p in d.glob("*.qml") if "pragma Singleton" in p.read_text()[:400]} for d in (Q / "services", Q)}
bad = set()
for p in Q.rglob("*.qml"):
    t = p.read_text()
    code = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', re.sub(r"//[^\n]*", "", t))
    dirs = {(p.parent / m).resolve() for m in re.findall(r'^import\s+"([^"]+)"', t, re.M)} | {p.parent.resolve()}
    for d, names in singles.items():
        if d.resolve() in dirs:
            continue
        for n in names:
            if re.search(r"(?<![\w.])" + n + r"\.\w", code) and not re.search(r"\bid:\s*" + n + r"\b", code):
                bad.add((str(p.relative_to(root)), n, str(d.relative_to(root))))
if bad:
    fail = 1
    print("Usan un singleton sin importar su carpeta:")
    for f, n, d in sorted(bad):
        print(f"  {f}: {n} (import de {d})")
sys.exit(fail)
