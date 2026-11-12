#!/usr/bin/env python3
"""dev/gen-pkgbuild.py — paquete del AUR `hyprfrijol-git` (packaging/aur/hyprfrijol-git/) a partir de
install/packages.tsv: depends = lo imprescindible (required) de la columna de Arch; optdepends = lo recomendado.

  dev/gen-pkgbuild.py           escribe PKGBUILD, hyprfrijol-git.install y .SRCINFO (este último con makepkg)
  dev/gen-pkgbuild.py --check   sale con 1 si el PKGBUILD del repo no está al día con packages.tsv

Publicarlo (lo hace el autor, con su cuenta del AUR):
  git clone ssh://aur@aur.archlinux.org/hyprfrijol-git.git && cp packaging/aur/hyprfrijol-git/* hyprfrijol-git/
  cd hyprfrijol-git && git add -A && git commit -m "…" && git push
"""
import pathlib, shutil, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "packaging/aur/hyprfrijol-git"
URL = "https://github.com/fsanchezlme97-ui/hyprfrijol"


def deps():
    req, opt = [], []
    for line in (ROOT / "install/packages.tsv").read_text().splitlines():
        c = line.split("\t")
        if line.startswith("#") or len(c) < 10 or c[2] in ("-", ""):
            continue
        pk = [p.removeprefix("aur:").strip() for p in c[2].split(",") if p.strip() and p.strip() != "-"]
        if c[1] == "required":
            req += pk
        elif c[1] == "recommended":
            opt += [f"{p}: {c[7].strip()}" for p in pk]
    seen = set(req)
    opt = [o for o in opt if o.split(":")[0] not in seen and not seen.add(o.split(":")[0])]
    return list(dict.fromkeys(req)), opt


def q(s):
    return "'" + s.replace("'", "'\\''") + "'"


def pkgbuild():
    req, opt = deps()
    nl = "\n         "
    return f"""# Maintainer: SrFrijol
# Generado por dev/gen-pkgbuild.py desde install/packages.tsv: no editar a mano.
pkgname=hyprfrijol-git
pkgver=0
pkgrel=1
pkgdesc='Escritorio completo sobre Hyprland con un shell de Quickshell (barra, paneles, asistente de IA, dictado)'
arch=('any')
url='{URL}'
license=('MIT')
depends=({nl.join(q(d) for d in req)})
optdepends=({nl.join(q(o) for o in opt)})
makedepends=('git')
provides=('hyprfrijol')
conflicts=('hyprfrijol')
install=hyprfrijol-git.install
source=('hyprfrijol::git+{URL}.git')
sha256sums=('SKIP')

pkgver() {{
  cd hyprfrijol
  git describe --long --tags --abbrev=7 | sed 's/^v//; s/\\([^-]*-g\\)/r\\1/; s/-/./g'
}}

package() {{
  cd hyprfrijol
  install -d "$pkgdir/opt/hyprfrijol"
  # sin lo que solo sirve para desarrollar (diseños, herramientas de pruebas)
  tar --exclude=.git --exclude=./design --exclude=./packaging -cf - . | tar -xf - -C "$pkgdir/opt/hyprfrijol"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -d "$pkgdir/usr/share/wayland-sessions"
  printf '%s\\n' '[Desktop Entry]' 'Name=Hyprland (HyprFrijol)' 'Comment=Hyprland con el shell HyprFrijol' \\
    'Exec=/opt/hyprfrijol/scripts/hf-session' 'Type=Application' 'DesktopNames=Hyprland' 'Keywords=tiling;wayland;compositor;' \\
    > "$pkgdir/usr/share/wayland-sessions/hyprfrijol.desktop"
  printf '%s\\n' '[Desktop Entry]' 'Name=HyprFrijol (modo seguro)' 'Comment=Hyprland mínimo para reparar HyprFrijol: sin shell ni plugins' \\
    'Exec=/opt/hyprfrijol/scripts/hf-session --safe' 'Type=Application' 'DesktopNames=Hyprland' 'Keywords=recovery;safe;rescue;' \\
    > "$pkgdir/usr/share/wayland-sessions/hyprfrijol-seguro.desktop"
}}
"""


INSTALL = """post_install() {
  echo ":: HyprFrijol está en /opt/hyprfrijol. Cada usuario, una vez (sin paquetes ni sesión, que ya pone el paquete):"
  echo "     /opt/hyprfrijol/install.sh --no-deps --no-session"
  echo "   Luego elige «Hyprland (HyprFrijol)» en el gestor de inicio. Las actualizaciones llegan con tu ayudante del AUR."
}

post_upgrade() {
  echo ":: HyprFrijol actualizado: dentro de la sesión, Ctrl + Super + R reinicia el shell (o cierra sesión y vuelve a entrar)."
}
"""


def main():
    text = pkgbuild()
    if "--check" in sys.argv:
        ok = (OUT / "PKGBUILD").exists() and (OUT / "PKGBUILD").read_text() == text and (OUT / "hyprfrijol-git.install").read_text() == INSTALL
        print("PKGBUILD al día" if ok else "PKGBUILD desactualizado: ejecuta dev/gen-pkgbuild.py")
        sys.exit(0 if ok else 1)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "PKGBUILD").write_text(text)
    (OUT / "hyprfrijol-git.install").write_text(INSTALL)
    if shutil.which("makepkg"):
        r = subprocess.run(["makepkg", "--printsrcinfo"], cwd=OUT, capture_output=True, text=True)
        if r.returncode == 0:
            (OUT / ".SRCINFO").write_text(r.stdout)
    print(f"{OUT.relative_to(ROOT)}: PKGBUILD, hyprfrijol-git.install" + (", .SRCINFO" if (OUT / ".SRCINFO").exists() else ""))


if __name__ == "__main__":
    main()
