-- hyprfrijol · Hyprland (0.57+, configuración en Lua)
--
-- Se arranca con la sesión «Hyprland (HyprFrijol)» o con `hf-session`, que ejecuta:
--   start-hyprland -- --config <repo>/config/hypr/hyprland.lua
-- No usa ~/.config/hypr, así que convive con cualquier otra configuración de Hyprland.
--
-- Tus cambios personales van en ~/.config/hyprfrijol/local.lua (nunca se sobrescribe).

-- Carpeta de este archivo → raíz del repo
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
local HOME = os.getenv("HOME")

HF = {
    root  = here:gsub("/config/hypr$", ""),
    hypr  = here,
    state = HOME .. "/.local/state/hyprfrijol",   -- colores, fondo y estado generados
    user  = HOME .. "/.config/hyprfrijol",        -- ajustes del usuario
}
HF.scripts = HF.root .. "/scripts"
HL = HF   -- nombre anterior (hypr-liquid): un local.lua antiguo con HL.terminal = … sigue funcionando

-- Primera vez tras el cambio de nombre: ~/.config|.local/state|.local/share|.cache/hypr-liquid → …/hyprfrijol (deja enlaces)
if os.execute then pcall(os.execute, "for d in \"$HOME/.config/hypr-liquid\" \"$HOME/.local/state/hypr-liquid\" \"$HOME/.local/share/hypr-liquid\" \"$HOME/.cache/hypr-liquid\"; do "
    .. "[ -d \"$d\" ] && [ ! -L \"$d\" ] && exec '" .. HF.scripts .. "/hf-migrate' --dirs-only --quiet; done; true") end
HF.qs      = "qs -p " .. HF.root .. "/config/quickshell"

package.path = HF.hypr .. "/?.lua;" .. package.path

-- Ejecuta un archivo Lua si existe; devuelve lo que devuelva el archivo
function HF.load(path)
    local f = io.open(path, "r")
    if not f then return nil end
    f:close()
    local ok, res = pcall(dofile, path)
    if not ok then
        hl.notification.create({ text = "HyprFrijol: error en " .. path .. ": " .. tostring(res), timeout = 8000 })
        return nil
    end
    return res
end

-- Colores base (Grafito). hf-apply genera settings.lua con la paleta y el estilo elegidos.
HF.colors = require("frijol.colors_default")

require("frijol.env")
require("frijol.input")
require("frijol.look")
require("frijol.rules")
require("frijol.binds")
require("frijol.floatsnap")    -- encajar ventanas flotantes al soltarlas en un borde (Snap.qml: snap drop)
require("frijol.autostart")

HF.load(HF.state .. "/settings.lua")  -- generado por hf-apply desde ~/.config/hyprfrijol/settings.json
require("frijol.workspaces")          -- espacios por pantalla (usa HF.wsPrimary / HF.wsKnown de settings.lua)
HF.load(HF.user .. "/local.lua")      -- ajustes personales
