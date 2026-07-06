-- 2-fancy-highlight-styles.lua
--
-- Adds three new highlight/underline styles to KOReader: Squiggly, Dash, and Dot.
-- KOReader already ships with "Shade" (lighten), "Invert", and "Underline"
-- (underscore) built in -- you don't need any extra code for those, they're
-- already in the style picker whenever you highlight text and tap the
-- underline/style icon.
--
-- INSTALLATION:
--   1. Copy this file into the "patches" folder inside your KOReader install,
--      e.g. koreader/patches/2-fancy-highlight-styles.lua
--      (create the "patches" folder if it doesn't exist yet)
--   2. Restart KOReader.
--   3. Select text (or tap an existing highlight) -> tap the underline/style
--      icon -> you'll now see Squiggly, Dash, and Dot alongside the stock
--      Shade, Invert, and Underline options.
--
-- No other files are needed. This is a single, self-contained patch.

local ReaderView = require("apps/reader/modules/readerview")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local _ = require("gettext")

-- ── Register the new style names so they show up in the style picker ──────
local highlight_styles = ReaderHighlight.getHighlightStyles()

local already_added = false
for _, style in ipairs(highlight_styles) do
    if style[2] == "squiggly" then
        already_added = true
        break
    end
end

if not already_added then
    table.insert(highlight_styles, { _("Squiggly"), "squiggly" })
    table.insert(highlight_styles, { _("Dash"), "dash" })
    table.insert(highlight_styles, { _("Dot"), "dot" })
end

-- ── Teach KOReader how to actually draw the three new styles ──────────────
local orig_drawHighlightRect = ReaderView.drawHighlightRect

ReaderView.drawHighlightRect = function(self, bb, _x, _y, rect, drawer, color, draw_note_mark)
    local custom_drawers = {
        squiggly = true,
        dash = true,
        dot = true,
    }

    if not custom_drawers[drawer] then
        -- Not one of ours: fall back to KOReader's normal drawing
        -- (this covers Shade, Invert, Underline, and anything else).
        return orig_drawHighlightRect(self, bb, _x, _y, rect, drawer, color, draw_note_mark)
    end

    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    color = color or Blitbuffer.COLOR_BLACK
    local is_color8 = Blitbuffer.isColor8(color)

    local function paint(px, py, pw, ph)
        if is_color8 then
            bb:paintRect(px, py, pw, ph, color)
        else
            bb:paintRectRGB32(px, py, pw, ph, color)
        end
    end

    if drawer == "squiggly" then
        local wave_w = 7   -- width of one wave cycle, in pixels
        local wave_h = 4   -- how tall the wave is, in pixels
        local cy = y + h - 2
        for i = 0, w - 1 do
            local dy = math.floor(math.sin(i / wave_w * math.pi) * wave_h + 0.5)
            paint(x + i, cy + dy, 1, Size.line.thick)
        end

    elseif drawer == "dash" then
        local dash_len = 8
        local gap_len = 4
        for i = 0, w, dash_len + gap_len do
            local dw = math.min(dash_len, w - i)
            if dw > 0 then
                paint(x + i, y + h - 1, dw, Size.line.thick)
            end
        end

    elseif drawer == "dot" then
        local dot_len = 3
        local gap_len = 3
        for i = 0, w, dot_len + gap_len do
            local dw = math.min(dot_len, w - i)
            if dw > 0 then
                paint(x + i, y + h - 1, dw, Size.line.thick)
            end
        end
    end

    -- Preserve the little note-mark indicator KOReader draws when a
    -- highlight has an attached note, so that still works normally.
    if self.highlight.note_mark ~= nil and draw_note_mark ~= nil then
        if self.highlight.note_mark == "underline" then
            paint(x, y + h - 1, w, Size.line.medium)
        end
    end
end
