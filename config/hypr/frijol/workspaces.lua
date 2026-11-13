-- Espacios por pantalla ("wsPerMonitor", por defecto sí): la pantalla k del orden usa del k·10+1 al k·10+10.
-- Orden: la principal (primaryMonitor si está conectada; si no, la más grande conectada: un nombre viejo, como
-- HDMI-A-1 tras añadir una gráfica, ya no se queda con el 1-10), luego las demás de Ajustes por nombre (las
-- desconectadas guardan su sitio; la principal guardada no, si no está) y las nuevas por id. 40-monitors.py da
-- HF.wsPrimary y HF.wsKnown (sin la principal).
-- Mismo cálculo en WsLabel.qml (barra y vista general); binds.lua (HF.wsBase) usa HF.wsOrder.
-- Al cargar: una regla por espacio y, a los que ya existen en una pantalla que no es la suya, se les cambia el número
-- (no se mueven: sus ventanas se quedan donde están). Al conectar o quitar una pantalla se rehace todo (sin recargar
-- la configuración: borraría los cambios de pantalla hechos en vivo, como la prueba de Ajustes › Pantallas).

function HF.wsOrder()
    local mons = {}
    for _, m in ipairs(hl.get_monitors() or {}) do if m.enabled ~= false then mons[#mons + 1] = m end end   -- (no las desactivadas)
    local here, prim = {}, HF.wsPrimary or ""
    for _, m in ipairs(mons) do here[m.name] = true end
    if prim == "" or not here[prim] then
        local best
        for _, m in ipairs(mons) do
            if not best or m.width * m.height > best.width * best.height then best = m end
        end
        if best then prim = best.name end
    end
    local order, seen = {}, {}
    local function add(n) if n ~= "" and not seen[n] then seen[n] = true; order[#order + 1] = n end end
    add(prim)
    for _, n in ipairs(HF.wsKnown or {}) do add(n) end
    table.sort(mons, function(a, b) return a.id < b.id end)
    for _, m in ipairs(mons) do add(m.name) end
    return order, here
end

-- Espacios con un número de otra pantalla (creados antes de cambiar el orden): al número que les toca en la suya,
-- con su misma posición (el 21 de la principal pasa a ser el 1) o el primero libre
local function renumber()
    local order = HF.wsOrder()
    local base = {}
    for k, name in ipairs(order) do base[name] = (k - 1) * 10 end
    for _ = 1, 3 do                                       -- varias vueltas: un hueco se libera al mover otro
        local used, moved = {}, false
        local list = hl.get_workspaces() or {}
        for _, w in ipairs(list) do if w.id then used[w.id] = true end end
        for _, w in ipairs(list) do
            local b = w.id and w.id > 0 and w.monitor and base[w.monitor.name]
            if b and (w.id <= b or w.id > b + 10) then
                local want = b + (w.id - 1) % 10 + 1
                if used[want] then
                    want = nil
                    for n = 1, 10 do if not used[b + n] then want = b + n; break end end
                end
                if want then
                    hl.dispatch(hl.dsp.workspace.change_id({ workspace = tostring(w.id), id = want }))
                    used[w.id], used[want], moved = nil, true, true
                end
            end
        end
        if not moved then break end
    end
end

-- Una regla por espacio (las anteriores se apagan al rehacerlas)
HF.wsRules = HF.wsRules or {}
local function apply()
    for _, r in ipairs(HF.wsRules) do r:set_enabled(false) end
    HF.wsRules = {}
    local order = HF.wsOrder()
    if HF.wsPerMonitor then
        for k, name in ipairs(order) do
            for n = 1, 10 do
                HF.wsRules[#HF.wsRules + 1] = hl.workspace_rule({ workspace = tostring((k - 1) * 10 + n), monitor = name, default = n == 1 })
            end
        end
    elseif HF.wsPrimary and order[1] then
        HF.wsRules[1] = hl.workspace_rule({ workspace = "1", monitor = order[1], default = true })
    end
    -- Apps que abren en la secundaria (secondaryApps, 40-monitors.py): la regla sigue a la secundaria de ahora
    if HF.secondaryApps and order[2] then
        HF.wsRules[#HF.wsRules + 1] = hl.window_rule({ name = "hf-secondary-apps", match = { class = HF.secondaryApps }, monitor = order[2] })
    end
end
apply()
if HF.wsPerMonitor then
    if #(hl.get_monitors() or {}) > 0 then hl.timer(renumber, { timeout = 300, type = "oneshot" })
    else hl.on("hyprland.start", function() hl.timer(renumber, { timeout = 300, type = "oneshot" }) end) end
end

-- Pantalla nueva o quitada: el orden cambia (sobre todo si era la principal). Con una pausa: una salida que se
-- enciende y apaga un instante no lo rehace varias veces.
local pending
local function later()
    if pending then pending:set_enabled(false) end
    pending = hl.timer(function() apply(); if HF.wsPerMonitor then renumber() end end, { timeout = 1500, type = "oneshot" })
end
hl.on("monitor.added", later)
hl.on("monitor.removed", later)
