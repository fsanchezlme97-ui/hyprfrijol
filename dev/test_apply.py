#!/usr/bin/env python3
"""Pruebas de config/apply: lo que cada módulo escribe para Hyprland a partir de los ajustes (sin tocar nada)."""
import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), ROOT / f"config/apply/{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def lua(name, settings):
    return "\n".join(load(name).hypr_lua(settings, {}))


def test_vrr():
    mon = lambda v: lua("40-monitors", {"monitors": {"DP-1": {"vrr": v}}})
    for value, written in ((True, 1), (False, 0), (0, 0), (1, 1), (2, 2), (3, 3), (9, 0), ("2); os.exit(", 0)):
        assert f"vrr = {written}" in mon(value), (value, mon(value))
    assert "vrr" not in lua("40-monitors", {"monitors": {"DP-1": {"scale": 1}}})


def test_hidden_from_capture():
    out = lua("35-windows", {"hiddenFromCapture": ["org.keepassxc.KeePassXC", 'mal"} ) os.exit(', "", "Bitwarden"]})
    rule = [line for line in out.splitlines() if "hf-private" in line]
    assert len(rule) == 1 and "no_screen_share = true" in rule[0], out
    assert "KeePassXC" in rule[0] and "Bitwarden" in rule[0] and "os.exit" not in out, rule
    assert "hf-private" not in lua("35-windows", {"hiddenFromCapture": []}) + lua("35-windows", {"hiddenFromCapture": "texto"})


def test_window_tabs_follow_the_theme():
    out = "\n".join(load("10-look").hypr_lua({}, {"p": "#FFC799", "onP": "#2E1D10", "s3": "#212124", "tv": "#B3B8BF"}))
    line = next(l for l in out.splitlines() if "groupbar" in l)
    assert "ffc799" in line.lower() and line.count("{") == line.count("}"), line


def test_named_scratchpads():
    pads = [{"name": 'Música "x"); os.exit(', "apps": ["spotify", 'mal")', "org.kde.elisa"]}, {"name": ""}, "roto"]
    pads += [{"name": f"p{i}"} for i in range(5)]
    out = lua("55-scratchpads", {"scratchpads": pads})
    assert "F1" in out and "F4" in out and "F5" not in out, out
    assert 'workspace = "special:hfpad-1 silent"' in out and "spotify|org" in out and 'mal"' not in out, out
    assert "Espacio oculto: Espacio 2" in out and '\\"x\\"' in out, out
    assert lua("55-scratchpads", {}) == "" == lua("55-scratchpads", {"scratchpads": "x"})
    # el hueco es fijo: quitar el primero no mueve al segundo
    slots = load("55-scratchpads").slotted
    kept = slots([{"slot": 2, "name": "b"}, {"slot": 2, "name": "repetido"}, {"name": "sin"}, {"slot": True, "name": "raro"}])
    assert [(n, p["name"]) for n, p in kept] == [(1, "repetido"), (2, "b"), (3, "sin"), (4, "raro")], kept
    only = lua("55-scratchpads", {"scratchpads": [{"slot": 3, "name": "Chat"}]})
    assert "SUPER + F3" in only and "hfpad-3" in only and "F1" not in only, only


if __name__ == "__main__":
    failed = 0
    for name, test in list(globals().items()):
        if name.startswith("test_"):
            try:
                test()
            except Exception as e:
                failed += 1
                print(f"{name}: {type(e).__name__}: {e}")
    sys.exit(1 if failed else 0)
