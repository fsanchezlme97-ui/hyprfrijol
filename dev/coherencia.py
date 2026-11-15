#!/usr/bin/env python3
"""dev/coherencia.py — dos comprobaciones de dev/lint.sh:
  · cada clave de ajustes que usa el shell tiene valor por defecto en config/defaults/settings.json (si no, cada
    sitio inventa el suyo);
  · cada programa que el código busca (command -v X, shutil.which("X")) está en la columna «órdenes» de
    install/packages.tsv, salvo los del sistema y las alternativas que no instalamos nosotros (SISTEMA);
  · cada .qml que usa un singleton (Time., Settings., Battery.…) importa su carpeta: si no, falla solo al usarse
    («ReferenceError: Time is not defined») y dev/check.sh no lo ve;
  · config/themes/palettes.json: los 15 roles en hex, parejas oscuro/claro recíprocas (la clara con "variant"),
    16 colores de terminal si los trae y el texto legible (≥ 4,5:1) sobre las superficies."""
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

# Paletas del repo
def _lum(h):
    v = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    v = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in v]
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]
def _con(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)
ROLES = ["bg", "s1", "s3", "s4", "p", "onP", "pc", "onPc", "sc", "onSc", "ter", "t", "tv", "o", "ov"]
pals = json.loads((root / "config/themes/palettes.json").read_text())
errs = []
for k, p in pals.items():
    hexes = [p.get(r) for r in ROLES] + list(p.get("ansi", []))
    if not all(isinstance(h, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", h) for h in hexes):
        errs.append(f"{k}: faltan roles o no son #RRGGBB")
        continue
    if "ansi" in p and len(p["ansi"]) != 16:
        errs.append(f"{k}: ansi con {len(p['ansi'])} colores (16)")
    if min(_con(p["t"], p[s]) for s in ("s1", "s3")) < 4.5:
        errs.append(f"{k}: el texto no llega a 4,5:1 sobre s1/s3")
    q = pals.get(p.get("pair", ""))
    if "pair" in p and (not q or q.get("pair") != k or bool(q.get("light")) == bool(p.get("light"))
                        or bool(p.get("variant")) == bool(q.get("variant"))):
        errs.append(f"{k}: pareja «{p['pair']}» no recíproca (una oscura y otra clara, solo una con variant)")
if errs:
    fail = 1
    print("Paletas (config/themes/palettes.json):")
    for e in errs:
        print("  " + e)
sys.exit(fail)
