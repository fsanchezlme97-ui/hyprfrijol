hl.config({
    input = {
        kb_layout    = "es,us",
        kb_options   = "grp:alt_shift_toggle",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
