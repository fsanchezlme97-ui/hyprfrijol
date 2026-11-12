local cfg = HF.hypr
local nested = (os.getenv("HF_NESTED") or os.getenv("HL_NESTED")) ~= nil   -- hf-session --nested: prueba dentro de otra sesión
-- En pruebas, sin la ventana de novedades de Hyprland: el HOME falso nunca recuerda haberla visto, salía en cada
-- prueba y hyprland-update-screen daba segfault al cerrarse
if nested then hl.config({ ecosystem = { no_update_news = true, no_donation_nag = true } }) end

hl.on("hyprland.start", function()
    hl.exec_cmd(HF.scripts .. "/hf-shell")                -- Quickshell (fondo, barra, avisos, polkit) + vigilante que lo reabre si se cae
    hl.exec_cmd("hf-wallpaper restore")
    if HF.cursor then hl.exec_cmd("hyprctl setcursor " .. HF.cursor .. " 24") end

    -- Servicios de sesión: solo en una sesión real, para no pisar los de la sesión anfitriona
    if not nested then
        -- Saludo de Sophia (aiAnnounceGreet): hf-ai lo mira y saluda una sola vez por sesión; espera a que suene el audio
        hl.exec_cmd("sh -c 'sleep 6; exec " .. HF.scripts .. "/hf-ai announce --greet'")
        hl.exec_cmd("dbus-update-activation-environment --all")
        hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HF_ROOT HF_SESSION PATH")
        -- Sin systemd (Void, Artix…) nadie arranca PipeWire por usuario: se lanza aquí. wireplumber y pipewire-pulse
        -- los arranca el propio pipewire si están en /etc/pipewire/pipewire.conf.d (./install.sh lo prepara en Void).
        hl.exec_cmd("sh -c '[ -d /run/systemd/system ] || ! command -v pipewire >/dev/null || pgrep -u \"$(id -u)\" -x pipewire >/dev/null || exec pipewire'")
        -- Llavero (contraseñas de Chrome, Wi-Fi, etc.), como en illogical-impulse
        hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
        -- Inactividad: la genera hf-apply (Ajustes › Energía); si aún no existe, la del repo
        hl.exec_cmd("sh -c 'f=" .. HF.state .. "/hypridle.conf; [ -f \"$f\" ] || f=" .. cfg .. "/hypridle.conf; exec hypridle -c \"$f\"'")
        -- Historial del portapapeles (texto e imágenes). Se conserva entre sesiones salvo que actives
        -- Ajustes › Productividad › Portapapeles › «Vaciar el portapapeles al iniciar sesión» (clipboardClearOnLogin).
        -- hf-clip store aplica el tamaño, la caducidad y las apps privadas antes de pasarlo a cliphist.
        hl.exec_cmd("sh -c '[ \"$(jq -r .clipboardClearOnLogin " .. HF.user .. "/settings.json 2>/dev/null)\" = true ] && cliphist wipe; exec wl-paste --watch " .. HF.scripts .. "/hf-clip store'")
        -- Apps de inicio XDG (~/.config/autostart, /etc/xdg/autostart): Hyprland no las lanza solo.
        -- Ajustes › Apps predeterminadas e inicio (autostartApps); hf-defaults evita las que chocan con el shell.
        hl.exec_cmd("sh -c 'sleep 3; [ \"$(jq -r .autostartApps " .. HF.user .. "/settings.json 2>/dev/null)\" = false ] || exec " .. HF.scripts .. "/hf-defaults autostart-run'")
        -- Escritorio remoto por RDP (Ajustes › Escritorio remoto, rdpServer): hypr-rdp para entrar desde Windows
        hl.exec_cmd("sh -c 'sleep 6; " .. HF.scripts .. "/hf-remote rdp boot; exec " .. HF.scripts .. "/hf-remote anydesk boot'")
        -- Descargas que quedaron a medias al cerrar la sesión (downloadsResume): se reanudan
        hl.exec_cmd("sh -c 'sleep 8; exec " .. HF.scripts .. "/hf-download boot'")
        -- Efectos de audio si los usas
        hl.exec_cmd("sh -c 'command -v easyeffects >/dev/null && exec easyeffects --hide-window --service-mode'")
        -- Icono de Tailscale en la bandeja: tailscaled no lo pone; espera a que la bandeja del shell esté lista
        hl.exec_cmd("sh -c 'command -v tailscale >/dev/null && sleep 3 && exec tailscale systray'")
        -- Plugins de Hyprland instalados con hyprpm (Ajustes › Plugins › «Cargar al iniciar», pluginsAutoload).
        -- -n avisa con una notificación; los errores (p. ej. cabeceras viejas tras actualizar Hyprland) avisan siempre.
        -- Sin plugins instalados (hyprpm list vacío) no se llama: si no, avisaba de cabeceras viejas sin motivo.
        hl.exec_cmd("sh -c '[ \"$(jq -r .pluginsAutoload " .. HF.user .. "/settings.json 2>/dev/null)\" = false ] || ! command -v hyprpm >/dev/null || [ -z \"$(hyprpm list 2>/dev/null)\" ] || exec hyprpm reload -n'")
    end
end)
