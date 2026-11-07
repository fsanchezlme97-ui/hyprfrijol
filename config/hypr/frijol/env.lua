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

-- Tema de Qt (KDE si está, como en tu sesión anterior) y menú «Abrir con» de Dolphin
local function exists(p) local f = io.open(p, "r"); if f then f:close(); return true end; return false end
if exists("/usr/lib/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so") then
    hl.env("QT_QPA_PLATFORMTHEME", "kde")
    hl.env("XDG_MENU_PREFIX", "plasma-")
end
-- Cursor: Bibata si está instalado
for _, dir in ipairs({ "/usr/share/icons/Bibata-Modern-Classic", (os.getenv("HOME") or "") .. "/.local/share/icons/Bibata-Modern-Classic" }) do
    if exists(dir .. "/index.theme") then hl.env("XCURSOR_THEME", "Bibata-Modern-Classic"); HF.cursor = "Bibata-Modern-Classic"; break end
end
-- Iconos para Quickshell (apps del escritorio, centro de aplicaciones) si nadie fija un tema:
-- el primero instalado de Papirus / Breeze / Adwaita (sin esto Qt cae en hicolor y faltan iconos)
if not os.getenv("QS_ICON_THEME") then
    for _, t in ipairs({ "Papirus-Dark", "Papirus", "breeze-dark", "breeze", "Adwaita" }) do
        if exists("/usr/share/icons/" .. t .. "/index.theme") or exists((os.getenv("HOME") or "") .. "/.local/share/icons/" .. t .. "/index.theme") then
            hl.env("QS_ICON_THEME", t); break
        end
    end
end
-- Apps de Flatpak en el lanzador
local home = os.getenv("HOME") or ""
hl.env("XDG_DATA_DIRS", home .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:" .. (os.getenv("XDG_DATA_DIRS") or ""))

-- Para los scripts y Quickshell
hl.env("HF_ROOT", HF.root)
hl.env("HF_SESSION", "1")
hl.env("PATH", HF.scripts .. ":" .. os.getenv("PATH"))

-- Programas (cámbialos en ~/.config/hyprfrijol/local.lua)
-- La primera instalada de cada lista (hf-launch), como en illogical-impulse.
-- Primero las de GNOME/libadwaita (siguen el tema: Ajustes › Apariencia › «Aplicar a las apps»); las de KDE, de alternativa.
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
