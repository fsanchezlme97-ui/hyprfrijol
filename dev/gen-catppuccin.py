#!/usr/bin/env python3
"""Genera el subconjunto de Catppuccin Icons (catppuccin/vscode-icons, MIT) que usa HyprFrijol.

Uso:  dev/gen-catppuccin.py <carpeta «extension» descomprimida del .vsix>
      (descarga: https://github.com/catppuccin/vscode-icons/releases → catppuccin-vsc-icons-X.Y.Z.vsix; es un zip)

Escribe:
  config/quickshell/assets/catppuccin/{mocha,latte}/*.svg   solo los iconos referenciados abajo
  config/quickshell/assets/catppuccin/LICENSE               licencia MIT original
  config/quickshell/components/catppuccin.js                tablas extensión/nombre/carpeta/lenguaje → icono
Para añadir tipos, amplía las listas y vuelve a ejecutarlo.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QS = os.path.join(ROOT, "config", "quickshell")
FLAVORS = ["mocha", "latte"]  # oscuro / claro

EXTS = """
sql db sqlite sqlite3 sh bash zsh fish ksh nu ps1 bat cmd py pyw pyi ipynb js mjs cjs jsx ts mts cts tsx vue svelte astro
qml qmlproject c h cpp cc cxx hpp hh cs java kt kts scala groovy gradle go rs swift dart rb php pl pm lua r jl ex exs erl
hs elm clj zig nim v d f90 asm s wasm sol html htm xhtml css scss sass less styl json jsonc json5 yaml yml toml ini conf cfg
env properties xml plist csv tsv md mdx markdown rst tex bib txt log diff patch lock graphql gql proto prisma tf hcl
nix dockerfile makefile mk cmake ninja meson vim el desktop service timer socket rules kdl hypr
pdf doc docx odt rtf xls xlsx ods ppt pptx odp epub
png jpg jpeg gif webp avif bmp ico svg tiff heic psd xcf kra blend
mp4 mkv webm mov avi m4v mp3 flac ogg opus wav m4a aac mid
zip tar gz tgz xz zst bz2 7z rar deb rpm iso apk appimage jar
ttf otf woff woff2 key pem crt pub asc gpg sig torrent exe dll so o a bin
""".split()

NAMES = """
makefile dockerfile containerfile docker-compose.yml docker-compose.yaml compose.yml package.json package-lock.json
pnpm-lock.yaml yarn.lock bun.lockb tsconfig.json jsconfig.json vite.config.js vite.config.ts cargo.toml cargo.lock
go.mod go.sum pyproject.toml requirements.txt pipfile poetry.lock gemfile composer.json cmakelists.txt meson.build
pkgbuild .gitignore .gitattributes .gitmodules .editorconfig .env .env.example .prettierrc .eslintrc .eslintrc.json
eslint.config.js .npmrc .nvmrc readme.md readme license license.md changelog.md contributing.md claude.md agents.md
justfile flake.nix shell.nix .bashrc .zshrc .profile hyprland.conf hyprland.lua
""".split()

# carpeta (minúsculas) → clave del tema; incluye las carpetas XDG en español
FOLDERS = {
    "src": "src", "source": "src", "lib": "lib", "dist": "dist", "build": "dist", "out": "dist", "bin": "src",
    "node_modules": "node_modules", "test": "test", "tests": "tests", "docs": "docs", "doc": "doc", "scripts": "scripts",
    "assets": "assets", "public": "public", "config": "config", ".config": ".config", ".git": ".git", ".github": ".github",
    ".vscode": ".vscode", "components": "components", "styles": "styles", "images": "images", "img": "img", "fonts": "fonts",
    "templates": "templates", "temp": "temp", "tmp": "tmp", "server": "server", "api": "api", "app": "app", "packages": "packages",
    "downloads": "downloads", "documents": "documents", "music": "music", "videos": "videos", "pictures": "images",
    "descargas": "downloads", "documentos": "documents", "música": "music", "musica": "music", "vídeos": "videos",
    "videos ": "videos", "imágenes": "images", "imagenes": "images", "plantillas": "templates", "público": "public",
    "publico": "public", ".local": "lib", ".cache": "temp", "proyectos": "src", "projects": "src", "dev": "src",
    "data": "data", "database": "database", "db": "db", "logs": "logs", "log": "log", "android": "android", "ios": "ios",
    "web": "web", "www": "www", "themes": "themes", "theme": "theme", "icons": "icons", "audio": "audio", "video": "video",
    "screenshots": "images", "capturas": "images", "wallpapers": "images", "fondos": "images",
}

# lenguaje del bloque de código del asistente → extensión o languageId equivalente
LANGS = {
    "sql": "sql", "mysql": "sql", "postgresql": "sql", "postgres": "sql", "psql": "sql", "pgsql": "sql", "sqlite": "sql",
    "plsql": "sql", "tsql": "sql", "mariadb": "sql", "bash": "sh", "sh": "sh", "zsh": "sh", "fish": "sh", "shell": "sh",
    "console": "sh", "terminal": "sh", "shellsession": "sh", "ksh": "sh", "nu": "sh", "powershell": "ps1", "ps1": "ps1",
    "bat": "bat", "python": "py", "py": "py", "python3": "py", "javascript": "js", "js": "js", "jsx": "jsx", "node": "js",
    "typescript": "ts", "ts": "ts", "tsx": "tsx", "qml": "qml", "c": "c", "cpp": "cpp", "c++": "cpp", "csharp": "cs",
    "cs": "cs", "java": "java", "kotlin": "kt", "kt": "kt", "go": "go", "golang": "go", "rust": "rs", "rs": "rs",
    "swift": "swift", "dart": "dart", "ruby": "rb", "rb": "rb", "php": "php", "perl": "pl", "lua": "lua", "r": "r",
    "julia": "jl", "elixir": "ex", "haskell": "hs", "zig": "zig", "html": "html", "xml": "xml", "svg": "svg",
    "css": "css", "scss": "scss", "sass": "sass", "less": "less", "json": "json", "jsonc": "jsonc", "json5": "json5",
    "yaml": "yaml", "yml": "yml", "toml": "toml", "ini": "ini", "conf": "conf", "cfg": "cfg", "env": "env",
    "dotenv": "env", "markdown": "md", "md": "md", "diff": "diff", "patch": "patch", "graphql": "graphql",
    "dockerfile": "dockerfile", "docker": "dockerfile", "makefile": "makefile", "make": "makefile", "cmake": "cmake",
    "nix": "nix", "vim": "vim", "tex": "tex", "latex": "tex", "csv": "csv", "vue": "vue", "svelte": "svelte",
    "hyprlang": "conf", "desktop": "desktop", "systemd": "service", "terraform": "tf", "proto": "proto",
}


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    ext_dir = sys.argv[1]
    theme = json.load(open(os.path.join(ext_dir, "dist", "mocha", "theme.json")))
    defs = theme["iconDefinitions"]
    fe, fnames, folders, lang_ids = theme["fileExtensions"], theme["fileNames"], theme["folderNames"], theme["languageIds"]
    fnames_l = {k.lower(): v for k, v in fnames.items()}
    folders_l = {k.lower(): v for k, v in folders.items()}
    folders_open = {k.lower(): v for k, v in theme.get("folderNamesExpanded", {}).items()}

    used = {theme["file"], theme["folder"], theme["folderExpanded"]}
    ext_map, name_map, folder_map, lang_map = {}, {}, {}, {}
    for e in EXTS:
        icon = fe.get(e) or fnames_l.get(e) or lang_ids.get(e)
        if icon:
            ext_map[e] = icon
    for n in NAMES:
        icon = fnames_l.get(n)
        if icon:
            name_map[n] = icon
    for name, key in FOLDERS.items():
        icon = folders_l.get(key)
        if icon:
            folder_map[name.strip()] = [icon, folders_open.get(key, icon)]
    for lang, e in LANGS.items():
        icon = fe.get(e) or fnames_l.get(e) or lang_ids.get(lang) or lang_ids.get(e)
        if icon:
            lang_map[lang] = icon
    for m in (ext_map, name_map, lang_map):
        used.update(m.values())
    for a, b in folder_map.values():
        used.update((a, b))
    missing = [i for i in used if i not in defs]
    if missing:
        sys.exit("faltan definiciones: %s" % missing)

    out = os.path.join(QS, "assets", "catppuccin")
    shutil.rmtree(out, ignore_errors=True)
    total = 0
    for fl in FLAVORS:
        os.makedirs(os.path.join(out, fl))
        for i in sorted(used):
            src = os.path.join(ext_dir, "dist", fl, defs[i]["iconPath"].lstrip("./"))
            dst = os.path.join(out, fl, i + ".svg")
            shutil.copyfile(src, dst)
            total += os.path.getsize(dst)
    shutil.copyfile(os.path.join(ext_dir, "LICENSE.txt"), os.path.join(out, "LICENSE"))

    js = os.path.join(QS, "components", "catppuccin.js")
    dump = lambda o: json.dumps(o, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    with open(js, "w") as f:
        f.write(""".pragma library
// Tablas de Catppuccin Icons (catppuccin/vscode-icons, MIT · assets/catppuccin/LICENSE).
// GENERADO por dev/gen-catppuccin.py — no editar a mano. Lo usa components/CatIcon.qml.
var FILE = %s, FOLDER = %s, FOLDER_OPEN = %s;
var EXT = %s;
var NAME = %s;
var DIR = %s;
var LANG = %s;

// nombre del icono para un archivo o carpeta (ruta o nombre)
function forPath(path, isDir, open) {
    var base = String(path || "").replace(/\\/+$/, "").split("/").pop();
    var low = base.toLowerCase();
    if (isDir) { var d = DIR[low]; return d ? d[open ? 1 : 0] : (open ? FOLDER_OPEN : FOLDER); }
    if (NAME[low]) return NAME[low];
    var parts = low.split(".");
    for (var i = 1; i < parts.length; i++) {           // «archivo.tar.gz» prueba «tar.gz» y luego «gz»
        var e = parts.slice(i).join(".");
        if (EXT[e]) return EXT[e];
    }
    return EXT[low] || FILE;
}

// nombre del icono para el lenguaje de un bloque de código ("" si no hay uno propio)
function forLang(lang) { return LANG[String(lang || "").toLowerCase()] || ""; }

// ruta relativa a assets/catppuccin/ (Mocha en temas oscuros, Latte en claros)
function rel(name, light) { return (light ? "latte" : "mocha") + "/" + name + ".svg"; }
""" % (dump(theme["file"]), dump(theme["folder"]), dump(theme["folderExpanded"]),
       dump(ext_map), dump(name_map), dump(folder_map), dump(lang_map)))
    print("%d iconos × %d sabores (%d kB) · %d extensiones · %d nombres · %d carpetas · %d lenguajes"
          % (len(used), len(FLAVORS), total // 1024, len(ext_map), len(name_map), len(folder_map), len(lang_map)))


if __name__ == "__main__":
    main()
