# Atajos: reasignaciones de Ajustes › Teclado (keybind-actions.json), atajos de las web apps y la lupa.
import json, os, pathlib, shutil, sys

def _here():
    for p in (pathlib.Path(os.environ.get("HF_ROOT", "/nonexistent")) / "config/apply",
              pathlib.Path(sys.argv[0]).resolve().parent.parent / "config/apply"):
        if p.is_dir():
            return p
    return None

def _q(v):
    return json.dumps(str(v), ensure_ascii=False)

def hypr_lua(s, c):
    out = []
    here = _here()
    actions = {}
    if here:
        try:
            actions = json.loads((here / "keybind-actions.json").read_text())
        except Exception:
            actions = {}
    for desc, o in (s.get("keybinds") or {}).items():
        lua = actions.get(desc)
        if not lua or desc.startswith("_") or not o.get("to"):
            continue
        if o.get("from"):
            out.append(f"hl.unbind({_q(o['from'])})")
        out.append(f"hl.bind({_q(o['to'])}, {lua}, {{ description = {_q(desc)} }})")
    # sobreamplificar (Ajustes › Sonido): la tecla de volumen sube hasta el 150 %
    if s.get("overAmplify"):
        out.append('hl.unbind("XF86AudioRaiseVolume")')
        out.append('hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })')
    # lupa: Super + / Super −
    if s.get("magnifier") and here:
        z = here / "bin" / "hf-zoom"
        # binds.lua ya trae una lupa básica (pasos de 0.3 hasta 3×) en las mismas teclas: se quita para que no
        # salten las dos a la vez
        for k in ("EQUAL", "MINUS", "code:21", "code:82", "code:86"):
            out.append(f'hl.unbind("SUPER + {k}")')
        out.append(f'hl.bind("SUPER + equal", hl.dsp.exec_cmd({_q(str(z) + " in")}), {{ description = "Lupa: acercar", repeating = true }})')
        out.append(f'hl.bind("SUPER + plus", hl.dsp.exec_cmd({_q(str(z) + " in")}), {{ description = "Lupa: acercar", repeating = true }})')
        out.append(f'hl.bind("SUPER + minus", hl.dsp.exec_cmd({_q(str(z) + " out")}), {{ description = "Lupa: alejar", repeating = true }})')
    return out
