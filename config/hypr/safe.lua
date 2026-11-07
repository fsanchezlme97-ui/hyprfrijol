-- hyprfrijol · MODO SEGURO (Hyprland 0.57+, Lua)
--
-- Lo arranca la entrada «HyprFrijol (modo seguro)» del login, o `hf-session --safe`:
--   start-hyprland -- --config <repo>/config/hypr/safe.lua
--
-- Es a propósito un archivo autónomo: no carga config/hypr/frijol/*, ni settings.lua (hf-apply), ni
-- profile.lua, ni ~/.config/hyprfrijol/local.lua, ni Quickshell, ni plugins (hyprpm). Así arranca aunque
-- la configuración normal esté rota. Abre una terminal con el menú de recuperación (hf-safe menu).
--
-- Atajos:  Super+Intro terminal · Super+R menú de recuperación · Super+Q cerrar ventana
--          Super+F pantalla completa · Super+1…5 espacios · Super+Mayús+Esc / Super+M salir al login

local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local ROOT = here:gsub("/config/hypr$", "")
local SAFE = ROOT .. "/scripts/hf-safe"
local HOME = os.getenv("HOME") or ""

-- Distribución de teclado: la de tus ajustes si se puede leer (settings.json), si no «us».
-- Solo se acepta texto simple (letras, guiones) para que un ajuste raro no rompa nada.
local layout = "us"
pcall(function()
    local f = io.open(HOME .. "/.config/hyprfrijol/settings.json", "r")
    if not f then return end
    local txt = f:read("*a"); f:close()
    local list = txt:match('"kbLayouts"%s*:%s*%[(.-)%]')
    if not list then return end
    local out = {}
    for l in list:gmatch('"([%w%-_]+)"') do out[#out + 1] = l; if #out == 4 then break end end
    if #out > 0 then layout = table.concat(out, ",") end
end)

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("HF_ROOT", ROOT)
hl.env("HF_SAFE", "1")
hl.env("PATH", ROOT .. "/scripts:" .. (os.getenv("PATH") or "/usr/bin"))

hl.config({
    input = {
        kb_layout    = layout,
        kb_options   = "grp:alt_shift_toggle",
        follow_mouse = 1,
        touchpad     = { natural_scroll = true, tap_to_click = true },
    },
    general = {
        gaps_in = 2, gaps_out = 4, border_size = 2, layout = "dwindle",
        col = { active_border = "rgba(e0a040ff)", inactive_border = "rgba(44444488)" },
    },
    decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
    animations = { enabled = false },
    ecosystem = { no_update_news = true, no_donation_nag = true },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0, background_color = "rgb(1c1b1f)" },
})

-- Terminal: hf-safe elige la primera instalada (kitty, foot, alacritty…); si faltara el script, kitty/foot/xterm
local function term(menu)
    local arg = menu and " menu" or ""
    return "sh -c '[ -x \"" .. SAFE .. "\" ] && exec \"" .. SAFE .. "\" terminal" .. arg
        .. "; for t in kitty foot alacritty xterm; do command -v $t >/dev/null && exec $t; done'"
end

local mod = "SUPER"
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(term(false)), { description = "Terminal" })
hl.bind(mod .. " + T",      hl.dsp.exec_cmd(term(false)))
hl.bind("CTRL + ALT + T",   hl.dsp.exec_cmd(term(false)))
hl.bind(mod .. " + R",      hl.dsp.exec_cmd(term(true)),  { description = "Restaurar ajustes (modo seguro)" })
hl.bind(mod .. " + Q",      hl.dsp.window.close(),        { description = "Cerrar ventana" })
hl.bind(mod .. " + F",      hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + SHIFT + ESCAPE", hl.dsp.exit(),         { description = "Salir al login" })
hl.bind(mod .. " + M",      hl.dsp.exit())
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
for i = 1, 5 do
    hl.bind(mod .. " + " .. i,            hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + code:" .. (9 + i), hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i,    hl.dsp.window.move({ workspace = i }))
end

hl.on("hyprland.start", function()
    hl.exec_cmd(term(true))
    hl.notification.create({ text = "HyprFrijol · modo seguro: sin shell ni plugins. Super+R abre «Restaurar ajustes», Super+M vuelve al login.", timeout = 12000 })
end)
