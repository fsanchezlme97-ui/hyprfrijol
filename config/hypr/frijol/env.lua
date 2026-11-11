hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Tema de Qt: qt6ct (config/apply/17-theme-apps.py le escribe la paleta y los iconos del tema). Si no está y sí el
-- tema de Plasma (alternativa: alguien con apps de KDE), ese, con el menú «Abrir con» de Dolphin.
local function exists(p) local f = io.open(p, "r"); if f then f:close(); return true end; return false end
local function qtTheme(name)
    for _, d in ipairs({ "/usr/lib/qt6/plugins", "/usr/lib64/qt6/plugins", "/usr/lib/x86_64-linux-gnu/qt6/plugins", "/usr/lib/aarch64-linux-gnu/qt6/plugins" }) do
        if exists(d .. "/platformthemes/" .. name) then return true end
    end
    return false
end
if qtTheme("libqt6ct.so") then
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
elseif qtTheme("KDEPlasmaPlatformTheme6.so") then
    hl.env("QT_QPA_PLATFORMTHEME", "kde")
    hl.env("XDG_MENU_PREFIX", "plasma-")
end
-- Vídeo de Qt (fondo del bloqueo y del selector) sin decodificar por hardware si hay una gráfica con nouveau: VA-API
-- abre la primera (renderD128, aquí la GT 710), sin firmware de vídeo, y Quickshell muere con SIGBUS (y con él el
-- bloqueo: Hyprland enseña su pantalla de «Oops» por el bloqueo caído).
-- shortcut: apaga el hardware aunque nouveau no sea la primera gráfica; afinar si el vídeo por CPU pesa.
if exists("/sys/module/nouveau/initstate") then hl.env("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", "none") end
-- Cursor: Bibata si está instalado
for _, dir in ipairs({ "/usr/share/icons/Bibata-Modern-Classic", (os.getenv("HOME") or "") .. "/.local/share/icons/Bibata-Modern-Classic" }) do
    if exists(dir .. "/index.theme") then hl.env("XCURSOR_THEME", "Bibata-Modern-Classic"); HF.cursor = "Bibata-Modern-Classic"; break end
end
-- Iconos para Quickshell (apps del escritorio, centro de aplicaciones) si nadie fija un tema:
-- el primero instalado de Papirus / Adwaita / Breeze (sin esto Qt cae en hicolor y faltan iconos)
if not os.getenv("QS_ICON_THEME") then
    for _, t in ipairs({ "Papirus-Dark", "Papirus", "Adwaita", "breeze-dark", "breeze" }) do
        if exists("/usr/share/icons/" .. t .. "/index.theme") or exists((os.getenv("HOME") or "") .. "/.local/share/icons/" .. t .. "/index.theme") then
            hl.env("QS_ICON_THEME", t); break
        end
    end
end
-- Apps de Flatpak en el lanzador
-- Sin repetidos: cada recarga de la config volvía a anteponer las rutas (hl.env cambia el entorno del propio
-- Hyprland) y con 160 entradas en XDG_DATA_DIRS las apps GTK tardaban ~15 s en abrir (iconos/mime/.desktop ×30).
local function pathlist(...)
    local out, seen = {}, {}
    for _, s in ipairs({ ... }) do
        for p in string.gmatch(s or "", "[^:]+") do
            if not seen[p] then seen[p] = true; out[#out + 1] = p end
        end
    end
    return table.concat(out, ":")
end
local home = os.getenv("HOME") or ""
hl.env("XDG_DATA_DIRS", pathlist(home .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share", os.getenv("XDG_DATA_DIRS")))

-- Para los scripts y Quickshell
hl.env("HF_ROOT", HF.root)
hl.env("HF_SESSION", "1")
hl.env("PATH", pathlist(HF.scripts, os.getenv("PATH")))

-- Programas (cámbialos en ~/.config/hyprfrijol/local.lua)
-- La primera instalada de cada lista (hf-launch), como en illogical-impulse.
-- Primero las de GNOME/libadwaita (siguen el tema: Ajustes › Apariencia › «Aplicar a las apps»); las demás (Qt/KDE…), de alternativa.
local function first(...)
    local q = {}
    for _, c in ipairs({ ... }) do q[#q + 1] = "'" .. c .. "'" end
    return HF.scripts .. "/hf-launch " .. table.concat(q, " ")
end
HF.terminal    = HF.terminal    or "kitty"
HF.files       = HF.files       or first("nautilus", "dolphin", "nemo", "thunar", "kitty -1 yazi")
HF.browser     = HF.browser     or first("google-chrome-stable", "zen-browser", "firefox", "brave", "chromium", "microsoft-edge-stable", "librewolf")
HF.codeEditor  = HF.codeEditor  or first("windsurf", "antigravity", "code", "codium", "cursor", "zed", "zeditor", "gnome-text-editor", "kate")
HF.textEditor  = HF.textEditor  or first("gnome-text-editor", "kate", "mousepad")
HF.office      = HF.office      or first("wps", "onlyoffice-desktopeditors", "libreoffice")
HF.volumeMixer = HF.volumeMixer or first("pavucontrol-qt", "pavucontrol", HF.qs .. " ipc call settings open sonido")
HF.taskManager = HF.taskManager or first("gnome-system-monitor", "resources", "plasma-systemmonitor --page-name Processes", "kitty -1 btop")
