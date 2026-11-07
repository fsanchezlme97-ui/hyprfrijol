# Teclado (distribuciones xkb, repetición, Bloq Num, Bloq Mayús), ratón, touchpad, foco y gestos.
# Ratón (Ajustes › Ratón y panel táctil): mouseSpeed (-1…1 → input.sensitivity), mouseAccel (adaptive|flat),
#   leftHanded, mouseNatural (input.natural_scroll), mouseScroll (input.scroll_factor), middlePaste (misc).
# Touchpad: tapToClick, tapAndDrag, naturalScroll, disableWhileTyping, clickMethod (areas|clickfinger),
#   touchpadScrollFactor; touchpadSpeed y touchpadScroll (2fg|edge) van por dispositivo (hl.device) a los
#   touchpads guardados en touchpadNames (los detecta la página) y a los que haya al cargar (hl.get_devices).
# Tableta: tabletOutput (pantalla a la que se asigna, "" = todas), tabletLeftHanded.
import json

GESTURE_LUA = {
    "vista": 'function() hl.dispatch(hl.dsp.global("hf:vista")) end',
    "ia": 'function() hl.dispatch(hl.dsp.global("hf:ia")) end',
    "spotlight": 'function() hl.dispatch(hl.dsp.global("hf:spotlight")) end',
    "notificaciones": 'function() hl.dispatch(hl.dsp.global("hf:notificaciones")) end',
    "ajustes": 'function() hl.dispatch(hl.dsp.global("hf:ajustes")) end',
    "bloquear": 'function() hl.exec_cmd("loginctl lock-session") end',
    "escritorio": 'function() hl.dispatch(hl.dsp.focus({ workspace = "empty" })) end',
}

def _b(v):
    return "true" if v else "false"

def _num(v, lo, hi, default):
    try:
        return round(max(lo, min(hi, float(v))), 2)
    except (TypeError, ValueError):
        return default

def hypr_lua(s, c):
    lays = [str(x) for x in (s.get("kbLayouts") or ["latam", "us"]) if x][:4] or ["us"]
    layouts = ",".join(l.split(":")[0] for l in lays)
    variants = ",".join((l.split(":", 1)[1] if ":" in l else "") for l in lays)
    opts = []
    sw = s.get("kbSwitch", "grp:ctrls_toggle")
    if sw and len(lays) > 1:
        opts.append(sw)
    if s.get("capsEscape"):
        opts.append("caps:escape")
    follow = 1 if s.get("focusOnHover", True) else 0
    out = [
        "hl.config({ input = {",
        f'    kb_layout = "{layouts}", kb_variant = "{variants}", kb_options = "{",".join(opts)}",',
        f'    repeat_delay = {int(s.get("kbRepeatDelay", 400))}, repeat_rate = {int(s.get("kbRepeatRate", 25))},',
        f'    numlock_by_default = {_b(s.get("numlock", True))}, follow_mouse = {follow},',
        f'    sensitivity = {_num(s.get("mouseSpeed", 0), -1, 1, 0)}, accel_profile = "{"flat" if s.get("mouseAccel") == "flat" else "adaptive"}",',
        f'    left_handed = {_b(s.get("leftHanded", False))}, natural_scroll = {_b(s.get("mouseNatural", False))}, scroll_factor = {_num(s.get("mouseScroll", 1), 0.2, 5, 1)},',
        f'    touchpad = {{ tap_to_click = {_b(s.get("tapToClick", True))}, natural_scroll = {_b(s.get("naturalScroll", True))}, disable_while_typing = {_b(s.get("disableWhileTyping", True))},',
        f'        tap_and_drag = {_b(s.get("tapAndDrag", True))}, clickfinger_behavior = {_b(s.get("clickMethod") == "clickfinger")}, scroll_factor = {_num(s.get("touchpadScrollFactor", 1), 0.2, 5, 1)} }},',
        f'    tablet = {{ output = {json.dumps(str(s.get("tabletOutput") or ""))}, left_handed = {_b(s.get("tabletLeftHanded", False))} }},',
        "} })",
        f'hl.config({{ misc = {{ middle_click_paste = {_b(s.get("middlePaste", True))} }} }})',
    ]
    tspeed = _num(s.get("touchpadSpeed", 0), -1, 1, 0)
    tscroll = "edge" if s.get("touchpadScroll") == "edge" else "2fg"
    if tspeed != 0 or tscroll != "2fg":
        names = [str(n) for n in (s.get("touchpadNames") or []) if isinstance(n, str) and n][:8]
        out += [
            "do",
            f"    local spec = {{ sensitivity = {tspeed}, scroll_method = \"{tscroll}\" }}",
            f"    local names, seen = {{ {', '.join(json.dumps(n) for n in names)} }}, {{}}",
            "    local ok, devs = pcall(hl.get_devices)",
            "    for _, d in ipairs(ok and devs or {}) do",
            "        local n = string.lower(d.name or \"\")",
            "        if n:find(\"touchpad\") or n:find(\"trackpad\") or n:find(\"synaptics\") then table.insert(names, d.name) end",
            "    end",
            "    for _, n in ipairs(names) do",
            "        if not seen[n] then seen[n] = true; hl.device({ name = n, sensitivity = spec.sensitivity, scroll_method = spec.scroll_method }) end",
            "    end",
            "end",
        ]
    if s.get("powerKey") == "menu":
        out.append('hl.bind("XF86PowerOff", function() hl.dispatch(hl.dsp.global("hf:energia")) end, { locked = true })')
    for key, fingers, direction, default in (("gesture3Up", 3, "up", "vista"), ("gesture3Down", 3, "down", "escritorio"),
                                             ("gesture4Up", 4, "up", "spotlight"), ("gesture4Down", 4, "down", "ninguna")):
        act = s.get(key, default)
        if act in GESTURE_LUA:
            out.append(f'hl.gesture({{ fingers = {fingers}, direction = "{direction}", action = {GESTURE_LUA[act]} }})')
    return out
