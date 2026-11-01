hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        focus_on_close = 1,
        sensitivity  = 0,
        repeat_rate  = 40,
        repeat_delay = 250,
        touchpad = { natural_scroll = true, tap_to_click = true },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
