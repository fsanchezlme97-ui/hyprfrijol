-- Encajar al arrastrar (ventanas flotantes): al soltar una ventana que se estaba arrastrando con el ratón, avisa al
-- shell con la posición del cursor; Snap.qml (IPC «snap drop») decide si cae en un borde (mitad), una esquina
-- (cuarto) o arriba (toda el área) según Ajustes › Escritorio › «Encajar al soltar en los bordes» (dragSnap).
-- Aquí solo se detecta el gesto: la ventana activa flotante cambió de sitio con el botón izquierdo pulsado y luego
-- se soltó. Si no se ve el botón pulsado durante el movimiento (teclado, scripts, la propia colocación), no hace
-- nada: así nunca encaja a mitad de un arrastre.
local last_addr, last_pos, moving, saw_down = nil, nil, false, false

local function tick()
    local w = hl.get_active_window()
    if not w or not w.floating or w.fullscreen ~= 0 then
        last_addr, last_pos, moving, saw_down = nil, nil, false, false
        return
    end
    local pos = w.at.x .. "," .. w.at.y
    local down = hl.is_key_down(272)          -- BTN_LEFT
    if down then
        saw_down = true
        if last_addr == w.address and last_pos and last_pos ~= pos then moving = true end
    else
        if moving and saw_down then
            local c = hl.get_cursor_pos()
            if c then
                hl.exec_cmd(HF.qs .. " ipc call snap drop " .. w.address .. " " .. math.floor(c.x) .. " " .. math.floor(c.y))
            end
        end
        moving, saw_down = false, false
    end
    last_addr, last_pos = w.address, pos
end

-- El temporizador solo con el compositor en marcha: en «Hyprland --verify-config» no hay monitores y crearlo ahí
-- tumba la verificación. Al recargar la configuración ya hay monitores; al arrancar, espera a hyprland.start.
local function start()
    if HF.floatsnap_timer then pcall(function() HF.floatsnap_timer:set_enabled(false) end) end
    HF.floatsnap_timer = hl.timer(tick, { timeout = 60, type = "repeat" })
end
local mons = hl.get_monitors and hl.get_monitors() or {}
if #mons > 0 then start() else hl.on("hyprland.start", start) end
