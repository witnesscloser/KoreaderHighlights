-- 2-fancy-highlight-styles.lua
--
-- Adds new highlight/underline styles to KOReader: Squiggly, Dash, Dot,
-- Double Underline, Zig-Zag, Circle, and Rectangle. KOReader already ships
-- with "Shade" (lighten), "Invert", and "Underline" (underscore) built in --
-- you don't need any extra code for those, they're already in the style
-- picker whenever you highlight text and tap the underline/style icon.
--
-- INSTALLATION:
--   1. Copy this file into the "patches" folder inside your KOReader install,
--      e.g. koreader/patches/2-fancy-highlight-styles.lua
--      (create the "patches" folder if it doesn't exist yet)
--   2. Restart KOReader.
--   3. Select text (or tap an existing highlight) -> tap the underline/style
--      icon -> you'll now see the new styles alongside the stock ones.
--
-- LINE THICKNESS:
--   Change the numbers in the "SETTINGS" section right below to make lines
--   thinner or thicker. Bigger number = thicker line. These are in pixels.
--
-- No other files are needed. This is a single, self-contained patch.

local ReaderView = require("apps/reader/modules/readerview")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local _ = require("gettext")

-- ─────────────────────────────────────────────────────────────────────────
-- ⚙️  SETTINGS -- edit these numbers to taste
-- ─────────────────────────────────────────────────────────────────────────
local LINE_THICKNESS = {
    squiggly           = 2,  -- thickness of the wave line
    dash               = 2,  -- thickness of each dash
    dot                = 2,  -- thickness of each dot
    double_underline   = 2,  -- thickness of EACH of the two lines
    zigzag             = 2,  -- thickness of the zig-zag line
    circle             = 2,  -- thickness of the circle/oval outline
    rectangle          = 2,  -- thickness of the rectangle outline
}

-- Gap between the two lines in "Double Underline"
local DOUBLE_UNDERLINE_GAP = 3

-- Size of one wave cycle for "Squiggly", in pixels (width, height)
local SQUIGGLY_SIZE = { w = 7, h = 4 }

-- Size of one zig-zag cycle, in pixels (width, height)
local ZIGZAG_SIZE = { w = 5, h = 5 }

-- Length of each dash / gap for "Dash", in pixels
local DASH_SIZE = { dash = 8, gap = 4 }

-- Length of each dot / gap for "Dot", in pixels
local DOT_SIZE = { dot = 3, gap = 3 }
-- ─────────────────────────────────────────────────────────────────────────

-- ── Register the new style names so they show up in the style picker ──────
local highlight_styles = ReaderHighlight.getHighlightStyles()

local NEW_STYLES = {
    { _("Squiggly"),          "squiggly" },
    { _("Dash"),              "dash" },
    { _("Dot"),               "dot" },
    { _("Double underline"),  "double_underline" },
    { _("Zig-zag"),           "zigzag" },
    { _("Circle"),            "circle" },
    { _("Rectangle"),         "rectangle" },
}

for _, new_style in ipairs(NEW_STYLES) do
    local already_added = false
    for _, style in ipairs(highlight_styles) do
        if style[2] == new_style[2] then
            already_added = true
            break
        end
    end
    if not already_added then
        table.insert(highlight_styles, new_style)
    end
end

-- ── Teach KOReader how to actually draw the new styles ─────────────────────
local orig_drawHighlightRect = ReaderView.drawHighlightRect

local custom_drawers = {
    squiggly = true,
    dash = true,
    dot = true,
    double_underline = true,
    zigzag = true,
    circle = true,
    rectangle = true,
}

ReaderView.drawHighlightRect = function(self, bb, _x, _y, rect, drawer, color, draw_note_mark)
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

    -- Outline-drawing helper for Rectangle: draws a border "thick" pixels
    -- wide using the same paint() used everywhere else, so it works on both
    -- color8 and RGB32 buffers.
    local function paintBorder(bx, by, bw, bh, thick)
        if bb.paintBorder then
            bb:paintBorder(bx, by, bw, bh, thick, color)
        else
            paint(bx, by, bw, thick)                     -- top
            paint(bx, by + bh - thick, bw, thick)         -- bottom
            paint(bx, by, thick, bh)                      -- left
            paint(bx + bw - thick, by, thick, bh)         -- right
        end
    end

    if drawer == "squiggly" then
        local thick = LINE_THICKNESS.squiggly
        local wave_w, wave_h = SQUIGGLY_SIZE.w, SQUIGGLY_SIZE.h
        local cy = y + h - 2
        for i = 0, w - 1 do
            local dy = math.floor(math.sin(i / wave_w * math.pi) * wave_h + 0.5)
            paint(x + i, cy + dy, 1, thick)
        end

    elseif drawer == "dash" then
        local thick = LINE_THICKNESS.dash
        local dash_len, gap_len = DASH_SIZE.dash, DASH_SIZE.gap
        for i = 0, w, dash_len + gap_len do
            local dw = math.min(dash_len, w - i)
            if dw > 0 then
                paint(x + i, y + h - thick, dw, thick)
            end
        end

    elseif drawer == "dot" then
        local thick = LINE_THICKNESS.dot
        local dot_len, gap_len = DOT_SIZE.dot, DOT_SIZE.gap
        for i = 0, w, dot_len + gap_len do
            local dw = math.min(dot_len, w - i)
            if dw > 0 then
                paint(x + i, y + h - thick, dw, thick)
            end
        end

    elseif drawer == "double_underline" then
        local thick = LINE_THICKNESS.double_underline
        paint(x, y + h - thick - DOUBLE_UNDERLINE_GAP - thick, w, thick)
        paint(x, y + h - thick, w, thick)

    elseif drawer == "zigzag" then
        local thick = LINE_THICKNESS.zigzag
        local zig_w, zig_h = ZIGZAG_SIZE.w, ZIGZAG_SIZE.h
        local cy = y + h - 2
        for i = 0, w - 1 do
            local phase = i % (zig_w * 2)
            local dy
            if phase < zig_w then
                dy = phase * zig_h / zig_w
            else
                dy = (zig_w * 2 - phase) * zig_h / zig_w
            end
            dy = math.floor(dy + 0.5) - math.floor(zig_h / 2)
            paint(x + i, cy + dy, 1, thick)
        end

    elseif drawer == "circle" then
        -- Drawn as an ellipse inscribed in the highlight box, since text
        -- selections are rectangular -- an ellipse reads as a "circled"
        -- annotation around the word/phrase without covering the text.
        local thick = LINE_THICKNESS.circle
        local cx, cy = x + w / 2, y + h / 2
        local rx, ry = w / 2, h / 2
        local steps = math.max(24, math.floor(w / 3))
        local prev_px, prev_py = nil, nil
        for i = 0, steps do
            local angle = (i / steps) * 2 * math.pi
            local px = math.floor(cx + rx * math.cos(angle))
            local py = math.floor(cy + ry * math.sin(angle))
            if prev_px then
                local dx = px - prev_px
                local dy = py - prev_py
                local dist = math.max(math.abs(dx), math.abs(dy), 1)
                for s = 0, dist do
                    local ix = prev_px + math.floor(dx * s / dist)
                    local iy = prev_py + math.floor(dy * s / dist)
                    paint(ix, iy, thick, thick)
                end
            end
            prev_px, prev_py = px, py
        end

    elseif drawer == "rectangle" then
        local thick = LINE_THICKNESS.rectangle
        paintBorder(x, y, w, h, thick)
    end

    -- Preserve the little note-mark indicator KOReader draws when a
    -- highlight has an attached note, so that still works normally.
    if self.highlight.note_mark ~= nil and draw_note_mark ~= nil then
        if self.highlight.note_mark == "underline" then
            paint(x, y + h - 1, w, Size.line.medium)
        end
    end
end
