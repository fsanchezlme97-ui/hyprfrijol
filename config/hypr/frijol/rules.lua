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

-- La ventana de chat de RustDesk: flota y sale centrada. Es un cuadro aparte (la conversación con el otro equipo):
-- en mosaico se comía media pantalla, con la conversación encima de la sesión remota. Solo el chat: la ventana
-- principal («… - RustDesk») sigue en mosaico como cualquier app. El título se compara entero («^(…)$»), por eso
-- el «.*» de los dos lados.
hl.window_rule({
    name  = "rustdesk-chat",
    match = { class = "^rustdesk$", title = "^(.*[Cc]hat.*|.*[Cc]onversaci..n.*)$" },
    float = true,
    center = true,
})

-- (Las apps no maximizan por su cuenta en mosaico y desplazamiento: regla "no-maximize" de config/apply/35-windows.py)

-- Juegos y apps de Windows (Wine / Proton: Genshin desde Epic, HoYoPlay, Battle.net…): flotan centradas a su tamaño.
-- En mosaico se encajaban en un hueco y Wine seguía dibujando a su tamaño: el contenido en una esquina, el resto negro
-- y los clics desplazados. Si el juego pide pantalla completa, la tiene. WinMode (Clásico) no las maximiza: keep().
-- Opacas: Wine pasa tal cual la transparencia por píxel de los lanzadores (HoYoPlay) y se veía lo de detrás a través
-- de toda la ventana (en Windows son opacas). Los menús y avisos de Wine van sin gestionar: no les afecta.
hl.window_rule({
    name   = "wine-float",
    match  = { class = "^(steam_proton|steam_app_.*|.*\\.exe)$" },
    float  = true,
    center = true,
    opaque = true,
})

-- Juegos: sin desenfoque y con tearing permitido
hl.window_rule({
    name  = "games",
    match = { class = "^(steam_app_.*|steam_proton|gamescope)$" },
    immediate = true,
    no_blur   = true,
})


-- «lee <archivo>» por voz (scripts/hf-voice): kitty con bat, flotante y centrado, para leer y cerrarlo con q
hl.window_rule({
    name   = "hf-lector",
    match  = { class = "^hf-lector$" },
    float  = true,
    center = true,
    size   = { "(monitor_w*0.6)", "(monitor_h*0.7)" },
})
