#!/usr/bin/env python3
"""dev/gen-settings-index.py — índice de búsqueda de la app de Ajustes.

Lee config/quickshell/modules/settings/sections/*.qml y escribe
config/quickshell/modules/settings/search-index.json con:
  rows:  [{ f: "<Archivo de la sección>", l: "<etiqueta>", s: "<subtítulo>", g: "<tarjeta>", t: "row|card|head" }]
         (etiquetas literales de SwRow, LabeledRow, InfoRow y Card, títulos de Section y los
          encabezados Txt { text: "…"; weight: Font.DemiBold } dentro de una tarjeta)
  keys:  { "<Archivo>": ["clave", …] }   claves de Settings que esa sección escribe
         (Settings.set("k"), SwRow key: "k", Settings.setMany({ k: … }), Confirm.change("…", { k: … }))
         → «Restaurar valores por defecto» de la cabecera de Ajustes

Vuelve a generarlo tras cambiar textos de las secciones:   dev/gen-settings-index.py
(--check: sale con 1 si el índice del repo está desactualizado)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SECT = ROOT / "config/quickshell/modules/settings/sections"
UI = ROOT / "config/quickshell/modules/settings/ui"   # tarjetas propias (Wallhaven, Mis temas…): cuentan en la sección que las usa
OUT = ROOT / "config/quickshell/modules/settings/search-index.json"
DEFAULTS = ROOT / "config/defaults/settings.json"

ROW_TYPES = {"SwRow": "row", "LabeledRow": "row", "InfoRow": "row", "Card": "row", "Section": "card"}
STR = r'"((?:[^"\\\n]|\\.)*)"'
# valor literal: "texto" seguido de ; salto de línea o }
LIT = STR + r'\s*(?=;|\n|\}|$)'


def strip_comments(src: str) -> str:
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in "\"'`":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            out.append(src[i:j + 1]); i = j + 1
        elif src.startswith("//", i):
            j = src.find("\n", i); i = n if j < 0 else j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2); i = n if j < 0 else j + 2
        else:
            out.append(c); i += 1
    return "".join(out)


def blocks(src: str):
    """Objetos QML: (tipo, inicio_cuerpo, fin_cuerpo, padres) por cada `Tipo {`."""
    res, stack, i, n = [], [], 0, len(src)
    while i < n:
        c = src[i]
        if c in "\"'`":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            i = j + 1; continue
        if c == "{":
            m = re.search(r'\b([A-Z]\w*)\s*$', src[max(0, i - 60):i])
            stack.append([m.group(1) if m else None, i + 1, len(res) if m else None])
            if m:
                res.append([m.group(1), i + 1, None, [s[2] for s in stack[:-1] if s[2] is not None]])
        elif c == "}" and stack:
            t, start, idx = stack.pop()
            if idx is not None:
                res[idx][2] = i
        i += 1
    return res


def own_text(src: str, a: int, b: int) -> str:
    """Cuerpo del objeto sin los bloques anidados (para leer solo sus propiedades)."""
    out, depth, i = [], 0, a
    while i < b:
        c = src[i]
        if c in "\"'`":
            j = i + 1
            while j < b and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            if depth == 0: out.append(src[i:j + 1])
            i = j + 1; continue
        if c == "{": depth += 1
        elif c == "}": depth -= 1
        elif depth == 0: out.append(c)
        i += 1
    return "".join(out)


def prop(text: str, name: str):
    m = re.search(r'(?:^|[\s;{])' + name + r':\s*' + LIT, text)
    return m.group(1).replace('\\"', '"') if m else None


def known_keys() -> set:
    keys = set(json.loads(DEFAULTS.read_text()))
    for f in (ROOT / "config/quickshell").rglob("*.qml"):
        keys |= set(re.findall(r'Settings\.get\(\s*"(\w+)"', f.read_text()))
    return keys


def written_keys(src: str, known: set) -> list:
    ks = set()
    for m in re.finditer(r'Settings\.set\(([^,()]*(?:\([^()]*\))?[^,()]*),', src):
        ks |= set(re.findall(r'"(\w+)"', m.group(1)))
    ks |= {k for k in re.findall(r'\bkey:\s*"(\w+)"', src) if k in known}
    for m in re.finditer(r'Settings\.(?:setMany|patch)\(|Confirm\.change\(', src):
        depth, i = 1, m.end()
        while i < len(src) and depth:
            depth += {"(": 1, ")": -1}.get(src[i], 0); i += 1
        arg = re.sub(STR, '""', src[m.end():i])
        ks |= {k for k in re.findall(r'([A-Za-z_]\w*)\s*:', arg) if k in known}
    return sorted(ks)


def index_file(path: Path, known: set, host: str = "", group: str = "", visited=None):
    """Filas de una sección; las de los componentes de ui/ que use van con ella (host) y bajo su tarjeta (group)."""
    visited = visited if visited is not None else set()
    visited.add(path.stem)
    host = host or path.stem
    src = strip_comments(path.read_text())
    bl = blocks(src)
    rows, seen = [], set()
    keys = set(written_keys(src, known))
    for typ, a, b, parents in bl:
        if b is None or typ in visited or typ in ROW_TYPES or not (UI / f"{typ}.qml").exists():
            continue
        card = next((prop(own_text(src, bl[p][1], bl[p][2]), "title") for p in reversed(parents) if bl[p][0] == "Section" and bl[p][2] is not None), None) or group
        r, k = index_file(UI / f"{typ}.qml", known, host, card, visited)
        rows += r; keys |= set(k)
    for typ, a, b, parents in bl:
        if b is None:
            continue
        txt = own_text(src, a, b)
        insec = any(bl[p][0] == "Section" for p in parents)
        card = next((prop(own_text(src, bl[p][1], bl[p][2]), "title") for p in reversed(parents) if bl[p][0] == "Section" and bl[p][2] is not None), None) or ""
        if typ in ROW_TYPES and "Se configura en" in src[a:b]:
            continue    # fila que remite a la sección dueña del ajuste: no es un resultado
        if typ in ROW_TYPES:
            label = prop(txt, "title" if typ in ("Section", "Card") else "label")
            if not label or len(label) < 3:     # «De», «A»: no sirven para buscar
                continue
            sub = prop(txt, "sub") or prop(txt, "hint") or ""
            kind = ROW_TYPES[typ]
            if kind == "card":
                card = ""
        elif typ == "Txt" and insec and re.search(r'weight:\s*Font\.DemiBold', txt) and not re.search(r'\bmuted:\s*true|\bsize:\s*(1[6-9]|[2-9]\d)', txt):
            label, sub, kind = prop(txt, "text"), "", "head"
            if not label or len(label) < 4 or len(label) > 40 or re.match(r'(Aún no|No hay|Sin )', label):
                continue
        else:
            continue
        k = (label, card)
        if k in seen:
            continue
        seen.add(k)
        card = card or (group if group != label else "")
        r = {"f": host, "l": label, "t": kind}
        if sub: r["s"] = sub
        if card and card != label: r["g"] = card
        rows.append(r)
    out, seen = [], set()      # sin repetidos (una tarjeta de ui/ usada dos veces en la misma sección)
    for r in rows:
        k = (r["l"], r.get("g", ""), r["f"])
        if k not in seen:
            seen.add(k); out.append(r)
    return out, sorted(keys)


def build() -> str:
    known = known_keys()
    rows, keys = [], {}
    for f in sorted(SECT.glob("*.qml")):
        r, k = index_file(f, known)
        rows += r
        if k: keys[f.stem] = k
    j = lambda o: json.dumps(o, ensure_ascii=False)
    return ('{"rows": [\n' + ",\n".join("  " + j(r) for r in rows) + '\n],\n"keys": {\n'
            + ",\n".join("  " + j(k) + ": " + j(v) for k, v in keys.items()) + "\n}}\n")


if __name__ == "__main__":
    data = build()
    if "--check" in sys.argv:
        ok = OUT.exists() and OUT.read_text() == data
        print("índice al día" if ok else "índice desactualizado: ejecuta dev/gen-settings-index.py")
        sys.exit(0 if ok else 1)
    OUT.write_text(data)
    d = json.loads(data)
    print(f"{OUT.relative_to(ROOT)}: {len(d['rows'])} filas, claves en {len(d['keys'])} secciones")
