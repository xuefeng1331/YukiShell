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

-- only pictures: a folder with videos, music or documents in it would otherwise put those in the list too (swayimg turns a video
-- into a sheet of frames, slowly, through ffmpeg). Anything that isn't a picture by its extension is taken out of the list, and
-- the video and font decoders are off so nothing slips through.
swayimg.format_conf = { video = { enable = false }, ttf = { enable = false } }

local picture = {}
for ext in ("jpg jpeg jpe jfif png apng gif webp avif heic heif jxl bmp dib ico cur tif tiff svg svgz tga exr hdr qoi dds "
         .. "pbm pgm ppm pnm pam pcx xpm xbm psd dng cr2 cr3 nef nrw arw srf sr2 orf rw2 raf pef srw x3f erf kdc 3fr mrw"):gmatch("%S+") do
  picture[ext] = true
end
local function is_picture(path)
  local ext = path:match("%.([^./]+)$")
  return ext ~= nil and picture[ext:lower()] == true
end

local listed = -1
local function only_pictures()
  if swayimg.imagelist.size == listed then return end
  local others, keep = {}, 0
  for _, e in ipairs(swayimg.imagelist.get()) do
    if is_picture(e.path) then keep = keep + 1 else others[#others + 1] = e.path end
  end
  if #others > 0 and keep > 0 then swayimg.imagelist.remove(others) end   -- never empty the list (a picture with an odd name)
  listed = swayimg.imagelist.size
end
swayimg.on_initialized(only_pictures)
-- files added to the folder while it's open (fsmon) are checked again the next time the picture changes
swayimg.viewer.on_image_change(only_pictures)
swayimg.slideshow.on_image_change(only_pictures)
swayimg.gallery.on_image_change(only_pictures)

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
