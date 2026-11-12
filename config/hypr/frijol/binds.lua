-- Atajos de hyprfrijol.
-- Incluyen los de illogical-impulse (misma tecla, misma función) para que no cambie la memoria muscular;
-- lo propio del rice va en teclas libres. Las descripciones las usan la chuleta (Super + /) y
-- Ajustes › Teclado (keybind-actions.json): no las cambies sin actualizar ese archivo.
local mod = "SUPER"
local exec = hl.dsp.exec_cmd
local function b(keys, dsp, opts) hl.bind(keys, dsp, opts) end
local S = HF.scripts
local function ipc(args) return exec(HF.qs .. " ipc call " .. args) end

-- Modo «Desplazamiento» (general:layout = scrolling, o una excepción del espacio): algunas teclas mueven entre
-- columnas cuando el espacio activo usa la cinta de columnas y la ventana activa no flota; si no, hacen lo de
-- siempre (other). HF.scroll lo usan también las reasignaciones de keybind-actions.json.
function HF.scrolling()
    local ws = hl.get_active_workspace()
    if not ws or ws.tiled_layout ~= "scrolling" then return false end
    local w = hl.get_active_window()
    return not (w and w.floating)
end
function HF.scroll(msg, other)
    return function()
        if HF.scrolling() then hl.dispatch(hl.dsp.layout(msg))
        elseif type(other) == "function" then other()
        elseif other then hl.dispatch(other) end
    end
end

-- ── Apps ──────────────────────────────────────────────────────────────────────
b(mod .. " + RETURN",  function() hl.exec_cmd(HF.terminal) end, { description = "Terminal" })
b(mod .. " + T",       function() hl.exec_cmd(HF.terminal) end)
b("CTRL + ALT + T",    function() hl.exec_cmd(HF.terminal) end)
b(mod .. " + E",       function() hl.exec_cmd(HF.files) end,    { description = "Archivos" })
b(mod .. " + W",       function() hl.exec_cmd(HF.browser) end,  { description = "Navegador" })
b(mod .. " + C",       function() hl.exec_cmd(HF.codeEditor) end, { description = "Editor de código" })
b(mod .. " + X",       function() hl.exec_cmd(HF.textEditor) end, { description = "Editor de texto" })
b("CTRL + " .. mod .. " + SHIFT + ALT + W", function() hl.exec_cmd(HF.office) end, { description = "Ofimática" })
b("CTRL + " .. mod .. " + V", function() hl.exec_cmd(HF.volumeMixer) end, { description = "Mezclador de volumen" })
b("CTRL + SHIFT + ESCAPE",    function() hl.exec_cmd(HF.taskManager) end, { description = "Administrador de tareas" })

-- ── Shell ─────────────────────────────────────────────────────────────────────
b(mod .. " + SPACE",     hl.dsp.global("hf:spotlight"),      { description = "Spotlight" })
b(mod .. " + SUPER_L",   hl.dsp.global("hf:spotlight"),      { release = true })   -- pulsar y soltar Super
b(mod .. " + SUPER_R",   hl.dsp.global("hf:spotlight"),      { release = true })
b(mod .. " + TAB",       hl.dsp.global("hf:vista"),          { description = "Vista general" })
b(mod .. " + A",         hl.dsp.global("hf:ia"),             { description = "Asistente / panel lateral" })
b(mod .. " + B",         hl.dsp.global("hf:ia"))
b(mod .. " + O",         hl.dsp.global("hf:ia"))
b(mod .. " + CTRL + A",  exec(S .. "/hf-ai summon"),        { description = "Asistente con la ventana actual" })
b(mod .. " + N",         hl.dsp.global("hf:ajustes"),        { description = "Ajustes rápidos" })
b("CTRL + " .. mod .. " + N", hl.dsp.global("hf:notificaciones"), { description = "Notificaciones" })
b(mod .. " + ALT + N",   ipc("notifs toggleDnd"),            { description = "No molestar" })
b(mod .. " + I",         hl.dsp.global("hf:ajustesapp"),     { description = "Ajustes" })
b(mod .. " + ALT + COMMA", hl.dsp.global("hf:ajustesapp"))
b(mod .. " + SHIFT + I", hl.dsp.global("hf:herramientas"),   { description = "Centro de aplicaciones" })
b(mod .. " + ALT + A",   ipc("settings open accesibilidad"), { description = "Accesibilidad" })
b(mod .. " + ALT + D",   hl.dsp.global("hf:dictado"),        { description = "Dictado" })   -- mantener: hablar · soltar: escribir
b(mod .. " + ALT + V",   hl.dsp.global("hf:comando"),        { description = "Comando de voz" })
b(mod .. " + ALT + H",   hl.dsp.global("hf:hablar"),         { description = "Hablar con el asistente" })   -- mantener: hablar · soltar: se lo pregunta   -- «pon Walk de Foo Fighters en YouTube»
b(mod .. " + V",         hl.dsp.global("hf:portapapeles"),   { description = "Portapapeles" })   -- Spotlight en modo «:»
b(mod .. " + PERIOD",    hl.dsp.global("hf:emojis"),         { description = "Emojis" })         -- Spotlight en modo «;»
b(mod .. " + SLASH",     hl.dsp.global("hf:atajos"),         { description = "Atajos de teclado" })
b(mod .. " + code:20",   hl.dsp.global("hf:atajos"))         -- tecla ' en teclado español
b(mod .. " + M",         hl.dsp.global("hf:musica"),         { description = "Controles de música" })
b(mod .. " + G",         hl.dsp.global("hf:widgets"),        { description = "Widgets" })
b(mod .. " + J",         hl.dsp.global("hf:barra"),          { description = "Mostrar / ocultar barra" })
b(mod .. " + K",         exec("sh -c 'pkill -x wvkbd-mobintl || pkill -x squeekboard || " .. S .. "/hf-launch wvkbd-mobintl squeekboard'"), { description = "Teclado en pantalla" })
b(mod .. " + Z",         hl.dsp.global("hf:enfoque"),        { description = "Sin distracciones" })
b(mod .. " + SHIFT + G", hl.dsp.global("hf:juego"),          { description = "Modo juego (sin animaciones ni efectos)" })
b(mod .. " + ALT + C",   hl.dsp.global("hf:cafeina"),        { description = "Cafeína" })
b(mod .. " + SHIFT + W", hl.dsp.global("hf:fondos"),         { description = "Fondos de pantalla" })
b("CTRL + " .. mod .. " + T", hl.dsp.global("hf:fondos"))
b(mod .. " + CTRL + W",  exec("hf-wallpaper next"),          { description = "Siguiente fondo" })
b("CTRL + " .. mod .. " + SHIFT + D", exec(S .. "/hf-apply toggle-mode"), { description = "Claro / oscuro" })
b("CTRL + " .. mod .. " + R", exec(HF.root .. "/scripts/hf-shell restart"),
                                                              { description = "Reiniciar el shell" })

-- ── Captura y utilidades ─────────────────────────────────────────────────────
b("PRINT",                hl.dsp.global("hf:captura"),          { description = "Captura" })
b("SHIFT + PRINT",        exec(S .. "/hf-capture screen"),      { description = "Captura de pantalla" })
b("CTRL + PRINT",         exec(S .. "/hf-capture screen"))
b(mod .. " + SHIFT + S",  hl.dsp.global("hf:captura"),          { description = "Captura (como Impr Pant)" })
b(mod .. " + SHIFT + X",  exec(S .. "/hf-capture region-ocr"),  { description = "Copiar texto de una zona (OCR)" })
b(mod .. " + SHIFT + T",  exec(S .. "/hf-capture region-translate"), { description = "Traducir una zona" })
b(mod .. " + SHIFT + A",  exec(S .. "/hf-capture region-ai"),   { description = "Preguntar a la IA por una zona" })
b(mod .. " + SHIFT + C",  hl.dsp.global("hf:color"),            { description = "Selector de color" })
b(mod .. " + SHIFT + R",  ipc("shell openWith captura grabar"), { description = "Grabar (otra vez: detener)" })
b(mod .. " + ALT + R",    ipc("shell openWith captura grabar"))

-- ── Ventanas ──────────────────────────────────────────────────────────────────
b(mod .. " + Q",           hl.dsp.window.close(),             { description = "Cerrar ventana" })
b(mod .. " + SHIFT + ALT + Q", exec("hyprctl kill"),          { description = "Forzar cierre (clic en la ventana)" })
b(mod .. " + D",           hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),  { description = "Maximizar" })
b(mod .. " + H",           hl.dsp.global("hf:minimizar"),     { description = "Minimizar" })
b(mod .. " + SHIFT + H",   hl.dsp.global("hf:restaurar"),     { description = "Restaurar minimizada" })
b(mod .. " + F",           hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Pantalla completa" })
b(mod .. " + ALT + F",     hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }), { description = "Pantalla completa simulada" })
b(mod .. " + ALT + SPACE", hl.dsp.window.float({ action = "toggle" }), { description = "Flotante" })
b("ALT + SPACE",           hl.dsp.global("hf:ventana"),        { description = "Menú de ventana" })
b(mod .. " + SHIFT + F",   hl.dsp.window.float({ action = "toggle" }))
b(mod .. " + SHIFT + SPACE", hl.dsp.global("hf:modoventanas"), { description = "Cambiar modo de ventanas" })
b(mod .. " + CTRL + SPACE",  hl.dsp.global("hf:modoespacio"),  { description = "Modo de ventanas de este espacio" })
b(mod .. " + P",           hl.dsp.window.pin(),               { description = "Fijar encima" })
-- En desplazamiento: Super + Alt + J saca la ventana a una columna propia; Super + ñ / ´ cambian el ancho de la
-- columna entre ⅓, ½, ⅔ y toda la pantalla (scrolling:explicit_column_widths)
b(mod .. " + ALT + J",     HF.scroll("promote", hl.dsp.layout("togglesplit")), { description = "Cambiar división / columna propia" })
for i, k in ipairs({ "SEMICOLON", "code:47" }) do
    b(mod .. " + " .. k, HF.scroll("colresize -conf", hl.dsp.layout("splitratio -0.1")),
      { repeating = true, description = i == 1 and "Proporción − / columna más estrecha" or nil })
end
for i, k in ipairs({ "APOSTROPHE", "code:48" }) do
    b(mod .. " + " .. k, HF.scroll("colresize +conf", hl.dsp.layout("splitratio +0.1")),
      { repeating = true, description = i == 1 and "Proporción + / columna más ancha" or nil })
end
b(mod .. " + CTRL + F",    HF.scroll("fit visible"),          { description = "Encajar las columnas a la vista" })
b("CTRL + " .. mod .. " + BACKSLASH", hl.dsp.window.resize({ x = 640, y = 480, "exact" }))
b(mod .. " + mouse:272",   hl.dsp.window.drag(),   { mouse = true })
b(mod .. " + mouse:273",   hl.dsp.window.resize(), { mouse = true })

-- Flechas: Super = acoplar (Snap) · Super + Alt = foco · Super + Mayús = mover
local dirs = { left = "l", right = "r", up = "u", down = "d" }
for k, d in pairs(dirs) do
    b(mod .. " + ALT + " .. k,   hl.dsp.focus({ direction = d }))
    b(mod .. " + SHIFT + " .. k, hl.dsp.window.move({ direction = d }))
end
b(mod .. " + left",  HF.scroll("focus l", hl.dsp.global("hf:snapleft")),  { description = "Mitad izquierda / columna anterior" })
b(mod .. " + right", HF.scroll("focus r", hl.dsp.global("hf:snapright")), { description = "Mitad derecha / columna siguiente" })
-- fuera del desplazamiento: la ventana a la pantalla de ese lado (y el foco con ella)
b(mod .. " + CTRL + SHIFT + left",  HF.scroll("swapcol l", hl.dsp.window.move({ monitor = "l" })), { description = "Mover columna ← / ventana a la pantalla de la izquierda" })
b(mod .. " + CTRL + SHIFT + right", HF.scroll("swapcol r", hl.dsp.window.move({ monitor = "r" })), { description = "Mover columna → / ventana a la pantalla de la derecha" })
b(mod .. " + CTRL + SHIFT + up",    hl.dsp.window.move({ monitor = "u" }), { description = "Ventana a la pantalla de arriba" })
b(mod .. " + CTRL + SHIFT + down",  hl.dsp.window.move({ monitor = "d" }), { description = "Ventana a la pantalla de abajo" })
b(mod .. " + up",    hl.dsp.global("hf:snapup"),    { description = "Maximizar / mitad superior" })
b(mod .. " + down",  hl.dsp.global("hf:snapdown"),  { description = "Restaurar / mitad inferior" })
b(mod .. " + ALT + W", hl.dsp.global("hf:snap"),    { description = "Ajustar ventana" })
b("ALT + TAB",         hl.dsp.global("hf:altnext"), { description = "Cambiar de ventana" })
b("ALT + SHIFT + TAB", hl.dsp.global("hf:altprev"), { description = "Cambiar de ventana (atrás)" })
b("ALT + code:49",     hl.dsp.global("hf:altapp"),  { description = "Ventanas de la misma app" })

-- ── Espacios ──────────────────────────────────────────────────────────────────
-- Espacios por pantalla ("wsPerMonitor", por defecto sí; el orden lo da HF.wsOrder, en workspaces.lua): la pantalla
-- k (0 = la principal) usa del k·10+1 al k·10+10 y Super + 1…0 van a los de la pantalla activa.
function HF.wsBase()
    if not HF.wsPerMonitor or not HF.wsOrder then return 0 end
    local m = hl.get_active_monitor()
    if not m then return 0 end
    for k, n in ipairs(HF.wsOrder()) do if n == m.name then return (k - 1) * 10 end end
    return 0
end
local function wsGo(i, move, follow)
    return function()
        local ws = HF.wsBase() + i
        if move then hl.dispatch(hl.dsp.window.move({ workspace = ws, follow = follow }))
        else hl.dispatch(hl.dsp.focus({ workspace = ws })) end
    end
end
-- anterior / siguiente: por número (crea el siguiente vacío); con espacios por pantalla, sin salir de los suyos
function HF.wsStep(d, move)
    return function()
        if not HF.wsPerMonitor then
            local r = (d > 0 and "r+" or "r-") .. math.abs(d)
            hl.dispatch(move and hl.dsp.window.move({ workspace = r }) or hl.dsp.focus({ workspace = r }))
            return
        end
        local base, ws = HF.wsBase(), hl.get_active_workspace()
        local n = ws and ws.id - base or 0
        n = (n >= 1 and n <= 10) and math.max(1, math.min(10, n + d)) or 1
        if move then hl.dispatch(hl.dsp.window.move({ workspace = base + n }))
        else hl.dispatch(hl.dsp.focus({ workspace = base + n })) end
    end
end
-- rueda: los espacios abiertos (con espacios por pantalla, solo los de la pantalla activa)
local function wsWheel(d)
    return function() hl.dispatch(hl.dsp.focus({ workspace = (HF.wsPerMonitor and "m" or "e") .. d })) end
end
for i = 1, 10 do
    local key, code = tostring(i % 10), 9 + i              -- 1…9, 0 · code:10…19 (fila de números)
    b(mod .. " + " .. key,             wsGo(i))
    b(mod .. " + code:" .. code,       wsGo(i))
    b(mod .. " + SHIFT + " .. key,     wsGo(i, true, true))
    b(mod .. " + ALT + " .. key,       wsGo(i, true, false))   -- enviar sin seguir
end
b(mod .. " + CTRL + left",   HF.wsStep(-1), { description = "Espacio anterior" })
b(mod .. " + CTRL + right",  HF.wsStep(1),  { description = "Espacio siguiente / nuevo" })
b(mod .. " + CTRL + up",     HF.wsStep(-5))
b(mod .. " + CTRL + down",   HF.wsStep(5))
-- Rueda: espacios; en desplazamiento, columnas (Super + Ctrl + rueda: espacios siempre)
b(mod .. " + mouse_down",    HF.scroll("focus r", wsWheel("+1")), { description = "Espacio / columna siguiente (rueda)" })
b(mod .. " + mouse_up",      HF.scroll("focus l", wsWheel("-1")), { description = "Espacio / columna anterior (rueda)" })
b(mod .. " + CTRL + mouse_down", wsWheel("+1"))
b(mod .. " + CTRL + mouse_up",   wsWheel("-1"))
b(mod .. " + SHIFT + mouse_up",   HF.wsStep(-1, true))
b(mod .. " + SHIFT + mouse_down", HF.wsStep(1, true))
b(mod .. " + SHIFT + Page_Up",    HF.wsStep(-1, true), { description = "Enviar al espacio anterior" })
b(mod .. " + SHIFT + Page_Down",  HF.wsStep(1, true),  { description = "Enviar al espacio siguiente" })
-- Consola desplegable (Super + º, la tecla a la izquierda del 1): una terminal que baja desde arriba sobre el
-- escritorio atenuado, en el espacio oculto «consola»; la primera vez se abre sola (on_created_empty). Ocupa la
-- mitad de arriba de la pantalla activa.
b(mod .. " + code:49", function()
    local m = hl.get_active_monitor()
    local h = m and math.floor(m.height / (m.scale or 1)) or 1080
    hl.workspace_rule({ workspace = "special:consola", gaps_out = { top = 8, right = 8, bottom = math.floor(h * 0.5), left = 8 },
                        on_created_empty = HF.terminal })
    hl.dispatch(hl.dsp.workspace.toggle_special("consola"))
end, { description = "Consola desplegable" })
-- Bloc de notas (scratchpad)
b(mod .. " + S",             hl.dsp.workspace.toggle_special("special"), { description = "Espacio oculto (scratchpad)" })
b("CTRL + " .. mod .. " + S", hl.dsp.workspace.toggle_special("special"))
b(mod .. " + mouse:275",     hl.dsp.workspace.toggle_special("special"))
b(mod .. " + ALT + S",       hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Enviar al espacio oculto" })

-- ── Pantalla: lupa ───────────────────────────────────────────────────────────
local function zoom(d)
    local z = hl.get_config("cursor:zoom_factor") or 1
    hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z + d)) } })
end
for _, k in ipairs({ "MINUS", "code:82" }) do b(mod .. " + " .. k, function() zoom(-0.3) end, { repeating = true }) end
for _, k in ipairs({ "EQUAL", "code:21", "code:86" }) do b(mod .. " + " .. k, function() zoom(0.3) end, { repeating = true }) end

-- ── Sesión ────────────────────────────────────────────────────────────────────
b(mod .. " + L",              exec(S .. "/hf-lock"),            { description = "Bloquear" })
b(mod .. " + SHIFT + L",      exec("systemctl suspend || loginctl suspend"), { locked = true, description = "Suspender" })
b(mod .. " + ESCAPE",         hl.dsp.global("hf:energia"),      { description = "Menú de energía" })
b("CTRL + ALT + DELETE",      hl.dsp.global("hf:energia"))
b("CTRL + SHIFT + ALT + " .. mod .. " + DELETE", exec("systemctl poweroff || loginctl poweroff"))
b(mod .. " + SHIFT + ESCAPE", hl.dsp.exit(),                    { description = "Salir de Hyprland" })

-- Máquinas virtuales: Super + Alt + F1 desactiva todos los atajos (y otra vez los reactiva)
hl.define_submap("virtual-machine", function()
    b(mod .. " + ALT + F1", function()
        if hl.get_current_submap() == "virtual-machine" then
            hl.dispatch(hl.dsp.exec_cmd("notify-send -a hyprfrijol 'Atajos activados'"))
            hl.dispatch(hl.dsp.submap("reset"))
        else
            hl.dispatch(hl.dsp.exec_cmd("notify-send -a hyprfrijol 'Atajos desactivados' 'Super + Alt + F1 para volver'"))
            hl.dispatch(hl.dsp.submap("virtual-machine"))
        end
    end, { submap_universal = true })
end)

-- ── Multimedia ───────────────────────────────────────────────────────────────
local media = { locked = true, repeating = true }
local osd = " && " .. HF.qs .. " ipc call osd popup "
b("XF86AudioRaiseVolume",  exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), media)
b("XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), media)
b("XF86AudioMute",         exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
b(mod .. " + SHIFT + M",   exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description = "Silenciar" })
b("XF86AudioMicMute",      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
b(mod .. " + ALT + M",     hl.dsp.global("hf:micro"),          { description = "Micrófono (dictado · asistente · silenciar)" })   -- lo del modo del botón de la barra
b(mod .. " + SHIFT + ALT + M", hl.dsp.global("hf:micro-modo"), { description = "Modo del micrófono" })
b("XF86MonBrightnessUp",   exec("brightnessctl s 5%+" .. osd .. "brillo"), media)
b("XF86MonBrightnessDown", exec("brightnessctl s 5%-" .. osd .. "brillo"), media)
b("XF86AudioPlay",  exec("playerctl play-pause"), { locked = true })
b("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
b("XF86AudioNext",  exec("playerctl next"),       { locked = true })
b("XF86AudioPrev",  exec("playerctl previous"),   { locked = true })
b(mod .. " + SHIFT + B", exec("playerctl previous"),   { locked = true, description = "Pista anterior" })
b(mod .. " + SHIFT + N", exec("playerctl next"),       { locked = true, description = "Pista siguiente" })
b(mod .. " + SHIFT + P", exec("playerctl play-pause"), { locked = true, description = "Reproducir / pausar" })
b(mod .. " + SHIFT + ALT + mouse:275", exec("playerctl previous"))
b(mod .. " + SHIFT + ALT + mouse:276", exec("playerctl next"))
