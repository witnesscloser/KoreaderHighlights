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
