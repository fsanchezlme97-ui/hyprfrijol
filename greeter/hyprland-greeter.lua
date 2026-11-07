-- Hyprland mínimo (0.57+, Lua) solo para mostrar el login de Quickshell (greeter/quickshell/shell.qml).
-- Se instala en /etc/greetd/hyprland-greeter.lua (ver README). Lo arranca greetd como el usuario «greeter».
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.config({
    -- Distribución de teclado del login (el botón «ES» de la barra cambia entre ellas)
    input = { kb_layout = "es,us", numlock_by_default = true },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 },
    general = { border_size = 0, gaps_in = 0, gaps_out = 0 },
    decoration = { blur = { enabled = false } },   -- el vidrio lo dibuja el propio greeter
    animations = { enabled = true },
    cursor = { inactive_timeout = 5 },
})
hl.on("hyprland.start", function()
    -- Al iniciar la sesión elegida, Quickshell termina y cerramos este Hyprland
    hl.exec_cmd("qs -p /etc/greetd/quickshell; hyprctl dispatch 'hl.dsp.exit()'")
end)
