-- swayimg: YukiShell's image viewer (linked to ~/.config/swayimg/init.lua by install.sh)
-- Only what differs from swayimg's defaults (/usr/share/swayimg/example.lua lists them all, with every key).
-- Just the picture: no title bar (Hyprland's border and the window rule frame it), the info text hidden until you press T.
--
--   ← / →  or  PgUp / PgDn   previous / next picture in the folder        scroll / + / -   zoom
--   drag                     move a zoomed picture                        Backspace        fit to window again
--   Enter                    thumbnails of the whole folder               F                full screen
--   [ / ]                    rotate                                       T                file info
--   S                        slide show                                   Esc / Q          close

local base, surface, text, pink = 0xf01e1e2e, 0xff313244, 0xffcdd6f4, 0xffeeacbe   -- Catppuccin Mocha, the YukiShell pink

swayimg.decoration = false
swayimg.imagelist.adjacent = true          -- opening one picture lists the rest of its folder too
swayimg.imagelist.order = "alpha"

swayimg.text.visible = false
swayimg.text.font = "JetBrainsMono Nerd Font"
swayimg.text.size = 16
swayimg.text.color = text
swayimg.text.shadow = 0xa0000000

swayimg.viewer.default_scale = "optimal"   -- fit big pictures to the window, small ones at their real size
swayimg.viewer.set_window_background(base)
swayimg.viewer.set_image_chessboard(16, 0xff313244, 0xff45475a)
swayimg.slideshow.set_window_background(0xff11111b)

swayimg.gallery.thumb_size = 180
swayimg.gallery.border_size = 3
swayimg.gallery.border_color = pink
swayimg.gallery.selected_color = surface
swayimg.gallery.unselected_color = 0xff181825
swayimg.gallery.window_color = base

-- arrows go through the folder instead of moving the picture; Q closes, like most viewers
swayimg.viewer.on_key("Left", function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("Right", function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("q", function() swayimg.exit() end)
swayimg.gallery.on_key("q", function() swayimg.exit() end)

-- scroll zooms around the pointer (swayimg's default only does that with Ctrl held)
swayimg.viewer.on_scroll(function(kmods, horizontal, vertical)
  if vertical and vertical ~= 0 then
    local mouse = swayimg.get_mouse_pos()
    local scale = swayimg.viewer.scale
    swayimg.viewer.set_abs_scale(scale - scale * vertical / 10.0, mouse.x, mouse.y)
  end
end)
