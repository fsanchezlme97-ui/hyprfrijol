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

-- (Las apps no maximizan por su cuenta en mosaico y desplazamiento: regla "no-maximize" de config/apply/35-windows.py)

-- Juegos: sin desenfoque y con tearing permitido
hl.window_rule({
    name  = "games",
    match = { class = "^(steam_app_.*|gamescope)$" },
    immediate = true,
    no_blur   = true,
})

