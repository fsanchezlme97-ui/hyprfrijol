-- Estilo "Liquid sobrio": esquinas poco redondeadas, vidrio con blur suave, sin brillos chillones.
local c = HF.colors

hl.config({
    general = {
        gaps_in          = 4,
        gaps_out         = 6,
        border_size      = 1,
        col = {
            active_border   = c.primary,
            inactive_border = c.outlineVariant,
        },
        layout           = "dwindle",
        resize_on_border = true,
    },

    -- Enfocar una ventana (desde el dock, Alt + Tab, al restaurarla) no lleva el cursor a su centro
    cursor = { no_warps = true },

    decoration = {
        rounding         = 8,
        active_opacity   = 1.0,
        inactive_opacity = 0.97,
        blur = {
            enabled    = true,
            size       = 8,
            passes     = 3,
            noise      = 0.015,
            contrast   = 0.95,
            brightness = 0.9,
            vibrancy   = 0.15,
            popups     = true,
        },
        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = "rgba(00000055)",
        },
    },

    animations = { enabled = true },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = c.surface,
    },
})

-- Movimiento: entrada «emphasized» (Material 3), salida rápida y un leve rebote elástico al abrir/mover
hl.curve("suave",   { type = "bezier", points = { {0.2, 0.8}, {0.2, 1} } })
hl.curve("entrada", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("salida",  { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("rebote",  { type = "bezier", points = { {0.34, 1.3}, {0.64, 1} } })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4.2, bezier = "rebote",  style = "popin 90%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2.6, bezier = "salida",  style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "rebote" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 3.5, bezier = "entrada" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 2.4, bezier = "salida" })
hl.animation({ leaf = "fadeSwitch",  enabled = true, speed = 4,   bezier = "entrada" })
hl.animation({ leaf = "border",      enabled = true, speed = 6,   bezier = "entrada" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4.8, bezier = "entrada", style = "slidefade 14%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.2, bezier = "entrada", style = "slidefadevert 18%" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 3.2, bezier = "entrada", style = "fade" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 2.2, bezier = "salida",  style = "fade" })

-- Vidrio para las capas del shell (barra, paneles, Spotlight) que dibuja Quickshell.
-- Todas usan el espacio de nombres "hf-…"; el fondo de pantalla no lleva blur.
hl.layer_rule({ match = { namespace = "^hf-.*" }, blur = true, blur_popups = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^hf-wallpaper$" }, blur = false, no_anim = true })
-- Fondos en movimiento: sin fundido de capa. Con él, al cambiar de vídeo el nuevo entraba transparente sobre el viejo
-- y el viejo salía con otro fundido: a medio camino se veía negro (o los dos mezclados)
hl.layer_rule({ match = { namespace = "^(mpvpaper|linux-wallpaperengine)$" }, blur = false, no_anim = true })
hl.layer_rule({ match = { namespace = "^hf-notifications$" }, animation = "slide right" })
