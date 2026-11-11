# Plugins de Hyprland (Ajustes › Plugins): opciones de config/tools/plugins.json guardadas en
#   plugins = { "<id>": { "on": true, "<opción>": valor, … } }
# «on» lo sincroniza la app con «hyprpm list»: solo se genera Lua para los plugins activados.
# Todo va dentro de una guarda: se ejecuta solo si Hyprland tiene el plugin cargado
# (hl.get_loaded_plugins() o la tabla hl.plugin.<ns>). hyprpm carga los plugins después de leer la
# config y Hyprland la vuelve a leer al cargarlos, así que en la segunda pasada la guarda ya se cumple.
# Sin el plugin (o con --verify-config) no se ejecuta nada, así que una opción desconocida nunca rompe la config.
# Cada bloque va además en pcall: un error de un plugin no corta el resto de settings.lua.
import json, os, pathlib, sys

def _root():
    for p in (pathlib.Path(os.environ.get("HF_ROOT", "/nonexistent")),
              pathlib.Path(sys.argv[0]).resolve().parent.parent):
        if (p / "config/tools/plugins.json").is_file():
            return p
    return None

def _q(v):
    return json.dumps(str(v), ensure_ascii=False)

def _rgba(h, a=1.0):
    h = str(h or "#000000").lstrip("#")
    if len(h) == 8:
        h = h[2:]
    try:
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    except ValueError:
        r, g, b = 0, 0, 0
    return "rgba(%02x%02x%02x%02x)" % (r, g, b, round(max(0, min(1, a)) * 255))

def _lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return _q(v)

def _value(opt, raw):
    """Valor de una opción validado contra su definición del catálogo (o el de por defecto)."""
    d = opt.get("def")
    t = opt.get("type")
    v = raw
    if t == "bool":
        v = raw if isinstance(raw, bool) else d
        return int(v) if opt.get("asInt") else v
    if t == "int":
        try:
            v = int(raw)
        except (TypeError, ValueError):
            v = d
        return max(opt.get("min", v), min(opt.get("max", v), v))
    if t == "choice":
        keys = [c[0] for c in opt.get("choices") or []]
        return raw if raw in keys else d
    return d

def _nest(tbl, path, v):
    parts = path.split(".")
    for p in parts[:-1]:
        tbl = tbl.setdefault(p, {})
    tbl[parts[-1]] = v

def _table(d, ind="    "):
    out = []
    for k, v in d.items():
        key = k if k.replace("_", "a").isalnum() and not k[0].isdigit() else f"[{_q(k)}]"
        out.append(f"{key} = " + (_table(v, ind + "    ") if isinstance(v, dict) else _lua(v)))
    return "{ " + ", ".join(out) + " }"

def _norm_key(k):
    return " + ".join(p.strip().upper() for p in str(k).split("+") if p.strip())

def hypr_lua(s, c):
    conf = s.get("plugins") or {}
    if not isinstance(conf, dict) or not any(isinstance(v, dict) and v.get("on") for v in conf.values()):
        return []
    root = _root()
    if not root:
        return []
    try:
        cat = json.loads((root / "config/tools/plugins.json").read_text()).get("plugins", [])
    except Exception:
        return ["-- 70-plugins.py: no se pudo leer config/tools/plugins.json"]

    # Teclas que el usuario ya reasignó en Ajustes › Teclado: no se pisan
    taken = {_norm_key(o.get("to")) for o in (s.get("keybinds") or {}).values() if isinstance(o, dict) and o.get("to")}
    used_keys = set()

    out = [
        "do",
        "    local loaded = {}",
        "    pcall(function() for _, p in ipairs(hl.get_loaded_plugins() or {}) do if p.name then loaded[p.name] = true end end end)",
        "    local function has(name, ns)",
        "        if loaded[name] then return true end",
        "        local ok, t = pcall(function() return hl.plugin[ns] end)",
        "        return ok and t ~= nil",
        "    end",
        "    local function run(name, fn)",
        "        local ok, err = pcall(fn)",
        '        if not ok then hl.notification.create({ text = "hyprfrijol: error al configurar el plugin " .. name .. ": " .. tostring(err), timeout = 8000 }) end',
        "    end",
    ]
    light = bool(c.get("light"))
    blocks = 0
    for p in cat:
        pid = p.get("id")
        u = conf.get(pid)
        if p.get("install") != "hyprpm" or not isinstance(u, dict) or not u.get("on") or not p.get("ns"):
            continue
        ns = p["ns"]
        vals = {o["key"]: _value(o, u.get(o["key"])) for o in p.get("options") or []}
        tbl = {}
        for o in p.get("options") or []:
            if o.get("lua"):
                _nest(tbl, o["lua"], vals[o["key"]])
        body = []

        def bind(key, fn_lua, desc):
            k = _norm_key(key)
            if not k:
                return
            if k in taken or k in used_keys:
                body.append(f"-- {k}: ya está en uso (Ajustes › Teclado u otro plugin), no se asigna")
                return
            used_keys.add(k)
            body.append(f"hl.unbind({_q(k)})")
            body.append(f"hl.bind({_q(k)}, function() {fn_lua} end, {{ description = {_q(desc)} }})")

        if pid == "hyprexpo":
            rad = s.get("rounding")
            tbl.update({"bg_col": _rgba(c.get("bg")), "border_color": _rgba(c.get("ov")), "border_width": 2,
                        "border_color_current": _rgba(c.get("p")), "border_color_hover": _rgba(c.get("tv")),
                        "tile_rounding": int(rad) if isinstance(rad, (int, float)) else 8, "gaps_out": vals.get("gaps", 8)})
            body.append(f"hl.config({{ plugin = {{ hyprexpo = {_table(tbl)} }} }})")
            bind(vals.get("bind"), 'hl.plugin.hyprexpo.expo("toggle")', "Vista de espacios (HyprExpo)")
            g = str(vals.get("gesture") or "")
            core = {"4:up": "gesture4Up", "4:down": "gesture4Down", "3:up": "gesture3Up"}.get(g)
            if core and s.get(core, "ninguna") not in ("ninguna", "", None):
                body.append(f"-- gesto {g}: ya lo usa {core} = {s.get(core)} (Ajustes › Escritorio), no se asigna")
            elif ":" in g:
                f, d = g.split(":", 1)
                body.append(f'hl.plugin.hyprexpo.gesture({{ fingers = {int(f)}, direction = {_q(d)}, action = "expo" }})')
        elif pid == "Hyprspace":
            tbl.update({"panelColor": _rgba(c.get("s1"), 0.85), "panelBorderColor": _rgba(c.get("ov")),
                        "workspaceActiveBackground": _rgba(c.get("s4"), 0.9), "workspaceInactiveBackground": _rgba(c.get("s3"), 0.7),
                        "workspaceActiveBorder": _rgba(c.get("p")), "workspaceInactiveBorder": _rgba(c.get("ov"))})
            body.append(f"hl.config({{ plugin = {{ overview = {_table(tbl)} }} }})")
            bind(vals.get("bind"), "hl.plugin.overview.toggle()", "Vista general (Hyprspace)")
        elif pid == "borders-plus-plus":
            tbl["col"] = {"border_1": _rgba(c.get("p"), 0.9), "border_2": _rgba(c.get("ter") or c.get("tv"), 0.8)}
            tbl["border_size_2"] = tbl.get("border_size_1", 4)
            tbl["natural_rounding"] = True
            body.append(f"hl.config({{ plugin = {{ borders_plus_plus = {_table(tbl)} }} }})")
        elif pid == "hyprglass":
            body.append(f"hl.plugin.hyprglass.config({{ default_theme = {_q('light' if light else 'dark')}, default_preset = {_q(vals.get('preset', 'subtle'))} }})")
        elif pid == "hyprgrass":
            body.append(f"hl.config({{ plugin = {{ hyprgrass = {_table(tbl)} }} }})")
            if vals.get("swipe"):
                body.append("hl.config({ gestures = { workspace_swipe_touch = true } })")
        elif pid == "csgo-vulkan-fix":
            body.append(f"hl.config({{ plugin = {{ csgo_vulkan_fix = {_table(tbl)} }} }})")
            res = str(vals.get("cs2") or "")
            if "x" in res:
                w, h = res.split("x", 1)
                body.append(f'hl.plugin.csgo_vulkan_fix.vkfix_app({{ app = "cs2", w = {int(w)}, h = {int(h)} }})')
        elif tbl:
            body.append(f"hl.config({{ plugin = {{ {ns} = {_table(tbl)} }} }})")
        if not body:
            continue
        blocks += 1
        out.append(f"    if has({_q(p.get('loaded') or pid)}, {_q(ns)}) then run({_q(p['name'])}, function()")
        out += ["        " + b for b in body]
        out.append("    end) end")
    out.append("end")
    return out if blocks else []
