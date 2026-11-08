-- Modo de ventanas (mosaico / flotante): las reglas del modo flotante las pone config/apply/35-windows.py.
HF.rules = HF.rules or {}

hl.window_rule({
    name  = "dialogs-float",
    match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol|nm-connection-editor|blueman-manager)$" },
    float = true,
    center = true,
})

-- PiP: arriba a la derecha, lo más pequeño posible, siempre visible. config/apply/52-pip.py la cambia por
-- una con el tamaño y la esquina de Ajustes y los márgenes de la barra (el shell la coloca después, Pip.qml)
HF.rules.pip = hl.window_rule({
    name  = "pip",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture|[Pp]antalla[-\\s]?en[-\\s]?[Pp]antalla|[Ii]mage[mn]?[-\\s]?(en|em|dentro de)[-\\s]?[Ii]mage[mn]?)(.*)$" },
    float = true,
    pin   = true,
    keep_aspect_ratio = true,
    -- sin `size`: con un tamaño fijo, `move` calcula con él y una ventana con tamaño mínimo mayor se salía
    move  = { "(monitor_w-window_w-12)", "12" },
})

-- Las apps no maximizan por su cuenta (respeta el mosaico)
hl.window_rule({ name = "no-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- Juegos: sin desenfoque y con tearing permitido
hl.window_rule({
    name  = "games",
    match = { class = "^(steam_app_.*|gamescope)$" },
    immediate = true,
    no_blur   = true,
})

-- Web apps del panel lateral (WhatsApp, YouTube, Pinterest): ventanas qml6 que el panel acopla
-- Nacen escondidas en el espacio especial «hfweb» (sin destello en pantalla): el panel trae la de la pestaña activa,
-- así se pueden precargar las demás en segundo plano
hl.window_rule({
    name  = "hf-webapps",
    match = { class = "^hf-webapp\\.qml6$" },
    workspace = "special:hfweb silent",
    float = true,
    border_size = 0,
    no_anim = true,
})
