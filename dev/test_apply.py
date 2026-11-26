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
