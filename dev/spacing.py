#!/usr/bin/env python3
"""dev/spacing.py — escala de espaciado de Math (docs/planes/temas.md §2.1): 4 / 8 / 12 / 16 / 24.

  dev/spacing.py           lista los espaciados y márgenes literales fuera de la escala (sale con 1 si hay)
  dev/spacing.py --fix     los lleva al valor de la escala más cercano (empates hacia arriba: 6 → 8, 10 → 12)

Solo números sueltos en spacing / margins / *Margin / *Padding de config/quickshell, sin Ui/ (la capa de Omarchy,
con su propio estilo). 0, 1 y 2 son filos y ajustes finos, y lo que pasa de 28 son desplazamientos, no huecos: se
quedan como están.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "config/quickshell"
SCALE = (4, 8, 12, 16, 24)
PROP = re.compile(r"\b((?:row|column)?[sS]pacing|margins|(?:left|right|top|bottom)Margin|(?:left|right|top|bottom|horizontal|vertical)?[pP]adding)"
                  r"(\s*:\s*)(\d+)(?=\s*(?:;|$|}|//))", re.M)


def snap(n):
    if n <= 2 or n > 28 or n in SCALE:
        return n
    return min(SCALE, key=lambda s: (abs(s - n), -s))


def main(fix):
    bad = 0
    for f in sorted(ROOT.rglob("*.qml")):
        if "Ui" in f.relative_to(ROOT).parts[:1]:
            continue
        t = f.read_text()
        out = PROP.sub(lambda m: m.group(1) + m.group(2) + str(snap(int(m.group(3)))), t)
        if out != t:
            n = sum(1 for m in PROP.finditer(t) if snap(int(m.group(3))) != int(m.group(3)))
            bad += n
            if fix:
                f.write_text(out)
            else:
                for m in PROP.finditer(t):
                    if snap(int(m.group(3))) != int(m.group(3)):
                        print(f"{f.relative_to(ROOT.parent.parent)}:{t.count(chr(10), 0, m.start()) + 1}: {m.group(0).strip()}"
                              f" → {snap(int(m.group(3)))}")
    if fix:
        print(f"{bad} valores llevados a la escala")
    return 0 if fix or not bad else 1


if __name__ == "__main__":
    assert [snap(n) for n in (0, 2, 3, 5, 6, 7, 9, 10, 11, 14, 18, 20, 22, 28, 30)] == [0, 2, 4, 4, 8, 8, 8, 12, 12, 16, 16, 24, 24, 24, 30]
    sys.exit(main("--fix" in sys.argv[1:]))
