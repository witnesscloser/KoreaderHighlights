-- 2-fancy-highlight-styles.lua
--
-- Adds new highlight/underline styles to KOReader: Wavy, Squiggly, Dash,
-- Dot, Double Underline, Zig-Zag, Circle, and Rectangle -- alongside the
-- stock Shade, Underline, Strikethrough, and Invert styles.
--
-- HOW TO USE:
--   Select text (or tap an existing highlight) as usual, then pick a style
--   the same way you always have (KOReader's own style list). All the new
--   styles above show up right there alongside the stock ones.
--
--   If the style you pick supports adjustable thickness, a number-picker
--   dialog (just like KOReader's own Font Size dialog) will pop up right
--   after -- but only when you actually change styles, not every single
--   time you highlight something.
--
--   Whatever thickness you set is remembered and reused automatically from
--   then on, until you change it again the same way.
--
-- INSTALLATION:
--   Copy this file into koreader/patches/2-fancy-highlight-styles.lua
--   (create the "patches" folder if it doesn't exist), then restart
--   KOReader.
--
-- No other files are needed. This is a single, self-contained patch.

local ReaderView = require("apps/reader/modules/readerview")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local SpinWidget = require("ui/widget/spinwidget")
local _ = require("gettext")

-- ─────────────────────────────────────────────────────────────────────────
-- ⚙️  DEFAULT THICKNESS -- only used the very first time, before you've
--     set anything yourself. After that, your own choices (saved to
--     KOReader's settings) take over automatically.
-- ─────────────────────────────────────────────────────────────────────────
local LINE_THICKNESS = {
    underline          = 2,
    wavy               = 2,
    squiggly           = 2,
    dash               = 2,
    dot                = 2,
    double_underline   = 2,
    zigzag             = 2,
    circle             = 2,
    rectangle          = 2,
}

local DOUBLE_UNDERLINE_GAP = 3
local WAVY_SIZE = { w = 12, h = 3 }
local SQUIGGLY_SIZE = { w = 7, h = 4 }
local ZIGZAG_SIZE = { w = 5, h = 5 }
local DASH_SIZE = { dash = 8, gap = 4 }
local DOT_SIZE = { dot = 3, gap = 3 }

-- Every style we add, plus which ones have adjustable thickness.
-- (label is only used the one time we register these with KOReader below.)
local STYLE_OPTIONS = {
    { key = "underscore",        label = _("Underline"),         thickness_key = "underline" },
    { key = "wavy",              label = _("Wavy"),              thickness_key = "wavy" },
    { key = "squiggly",          label = _("Squiggly"),          thickness_key = "squiggly" },
    { key = "dash",              label = _("Dash"),              thickness_key = "dash" },
    { key = "dot",               label = _("Dot"),               thickness_key = "dot" },
    { key = "double_underline",  label = _("Double underline"),  thickness_key = "double_underline" },
    { key = "zigzag",            label = _("Zig-zag"),           thickness_key = "zigzag" },
    { key = "circle",            label = _("Circle"),            thickness_key = "circle" },
    { key = "rectangle",         label = _("Rectangle"),         thickness_key = "rectangle" },
}

local THICKNESS_BY_DRAWER = {}
for _, opt in ipairs(STYLE_OPTIONS) do
    if opt.thickness_key then
        THICKNESS_BY_DRAWER[opt.key] = opt.thickness_key
    end
end
-- ─────────────────────────────────────────────────────────────────────────

-- ── Load any previously-saved thickness values from KOReader's settings ───
local THICKNESS_SETTINGS_KEY = "fancy_highlight_thickness"
local DRAWER_SETTINGS_KEY = "highlight_drawer"

local saved_thickness = G_reader_settings:readSetting(THICKNESS_SETTINGS_KEY)
if type(saved_thickness) == "table" then
    for key, value in pairs(saved_thickness) do
        if LINE_THICKNESS[key] ~= nil and type(value) == "number" then
            LINE_THICKNESS[key] = value
        end
    end
end

local function persistThicknessSettings()
    G_reader_settings:saveSetting(THICKNESS_SETTINGS_KEY, LINE_THICKNESS)
end

-- ── Register the new style names so they show up in KOReader's own style
--    list (this is already confirmed working on your device) ──────────────
local highlight_styles = ReaderHighlight.getHighlightStyles()
for _, opt in ipairs(STYLE_OPTIONS) do
    local already_added = false
    for _, style in ipairs(highlight_styles) do
        if style[2] == opt.key then
            already_added = true
            break
        end
    end
    if not already_added then
        table.insert(highlight_styles, { opt.label, opt.key })
    end
end

-- ── Teach KOReader how to actually draw the new styles ─────────────────────
local orig_drawHighlightRect = ReaderView.drawHighlightRect

local custom_drawers = {
    wavy = true, squiggly = true, dash = true, dot = true,
    double_underline = true, zigzag = true, circle = true, rectangle = true,
}

ReaderView.drawHighlightRect = function(self, bb, _x, _y, rect, drawer, color, draw_note_mark)
    if not custom_drawers[drawer] then
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

    local function paintBorder(bx, by, bw, bh, thick)
        if bb.paintBorder then
            bb:paintBorder(bx, by, bw, bh, thick, color)
        else
            paint(bx, by, bw, thick)
            paint(bx, by + bh - thick, bw, thick)
            paint(bx, by, thick, bh)
            paint(bx + bw - thick, by, thick, bh)
        end
    end

    if drawer == "wavy" then
        local thick = LINE_THICKNESS.wavy
        local wave_w, wave_h = WAVY_SIZE.w, WAVY_SIZE.h
        local cy = y + h - 2
        for i = 0, w - 1 do
            local dy = math.floor(math.sin(i / wave_w * math.pi) * wave_h + 0.5)
            paint(x + i, cy + dy, 1, thick)
        end

    elseif drawer == "squiggly" then
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
            if dw > 0 then paint(x + i, y + h - thick, dw, thick) end
        end

    elseif drawer == "dot" then
        local thick = LINE_THICKNESS.dot
        local dot_len, gap_len = DOT_SIZE.dot, DOT_SIZE.gap
        for i = 0, w, dot_len + gap_len do
            local dw = math.min(dot_len, w - i)
            if dw > 0 then paint(x + i, y + h - thick, dw, thick) end
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

    if self.highlight.note_mark ~= nil and draw_note_mark ~= nil then
        if self.highlight.note_mark == "underline" then
            paint(x, y + h - 1, w, Size.line.medium)
        end
    end
end

-- Apply user's custom thickness to the stock "Underline" style too.
local orig_drawHighlightRect2 = ReaderView.drawHighlightRect
ReaderView.drawHighlightRect = function(self, bb, _x, _y, rect, drawer, color, draw_note_mark)
    if drawer == "underscore" and LINE_THICKNESS.underline then
        local orig_thick = Size.line.medium
        Size.line.medium = LINE_THICKNESS.underline
        local ok, err = pcall(orig_drawHighlightRect2, self, bb, _x, _y, rect, drawer, color, draw_note_mark)
        Size.line.medium = orig_thick
        if not ok then error(err) end
        return
    end
    return orig_drawHighlightRect2(self, bb, _x, _y, rect, drawer, color, draw_note_mark)
end

-- ── Remember the last-used style, and offer a thickness picker right after
--    you actually change styles ────────────────────────────────────────────
-- Rather than guessing which button/menu triggers a style change (which
-- turned out to be wrong before), this hooks the two places KOReader
-- actually commits a highlight's style: saving a brand-new highlight, and
-- writing/updating an existing one's annotation. Both fire regardless of
-- which menu the user tapped through, so this works no matter how styles
-- get chosen on this device.

local last_seen_drawer = G_reader_settings:readSetting(DRAWER_SETTINGS_KEY)

local function persistDrawer(drawer)
    if drawer then
        G_reader_settings:saveSetting(DRAWER_SETTINGS_KEY, drawer)
    end
end

local function maybeOfferThicknessPicker(drawer, dirty_target)
    if drawer == last_seen_drawer then
        return -- same style as before: don't nag with a popup every time
    end
    last_seen_drawer = drawer

    local thickness_key = THICKNESS_BY_DRAWER[drawer]
    if not thickness_key then
        return -- this style doesn't have adjustable thickness
    end

    local label = drawer
    for _, opt in ipairs(STYLE_OPTIONS) do
        if opt.key == drawer then
            label = opt.label
            break
        end
    end

    UIManager:show(SpinWidget:new{
        value = LINE_THICKNESS[thickness_key] or 2,
        value_min = 1,
        value_max = 12,
        value_step = 1,
        value_hold_step = 2,
        title_text = label .. " " .. _("thickness"),
        ok_text = _("Apply"),
        callback = function(spin)
            LINE_THICKNESS[thickness_key] = spin.value
            persistThicknessSettings()
            if dirty_target then
                UIManager:setDirty(dirty_target, "ui")
            end
        end,
    })
end

local orig_saveHighlight = ReaderHighlight.saveHighlight
if orig_saveHighlight then
    ReaderHighlight.saveHighlight = function(self, ...)
        local result = orig_saveHighlight(self, ...)
        if self.view and self.view.highlight and self.view.highlight.saved_drawer then
            local drawer = self.view.highlight.saved_drawer
            persistDrawer(drawer)
            maybeOfferThicknessPicker(drawer, self.dialog)
        end
        return result
    end
end

local orig_writePdfAnnotation = ReaderHighlight.writePdfAnnotation
if orig_writePdfAnnotation then
    ReaderHighlight.writePdfAnnotation = function(self, action, item, ...)
        local result = orig_writePdfAnnotation(self, action, item, ...)
        if item and item.drawer and action == "save" then
            persistDrawer(item.drawer)
            maybeOfferThicknessPicker(item.drawer, self.dialog)
        end
        return result
    end
end

-- ── Backup access: a Tools-menu entry for thickness, guaranteed reachable
--    regardless of whether the auto-popup above ever fires on your setup.
--    This doesn't depend on knowing how your fork commits a style change --
--    it only needs KOReader's standard menu-registration API to work.
local ok_menu, menu_err = pcall(function()
    local ReaderUI = require("apps/reader/readerui")
    local logger = require("logger")

    local THICKNESS_MENU_ORDER = {
        { key = "underline",         label = _("Underline") },
        { key = "wavy",              label = _("Wavy") },
        { key = "squiggly",          label = _("Squiggly") },
        { key = "dash",              label = _("Dash") },
        { key = "dot",               label = _("Dot") },
        { key = "double_underline",  label = _("Double underline") },
        { key = "zigzag",            label = _("Zig-zag") },
        { key = "circle",            label = _("Circle") },
        { key = "rectangle",         label = _("Rectangle") },
    }

    local function showThicknessPickerFromMenu(thickness_key, label)
        UIManager:show(SpinWidget:new{
            value = LINE_THICKNESS[thickness_key] or 2,
            value_min = 1,
            value_max = 12,
            value_step = 1,
            value_hold_step = 2,
            title_text = label .. " " .. _("thickness"),
            ok_text = _("Apply"),
            callback = function(spin)
                LINE_THICKNESS[thickness_key] = spin.value
                persistThicknessSettings()
            end,
        })
    end

    local ThicknessMenu = {}
    function ThicknessMenu:addToMainMenu(menu_items)
        local sub_item_table = {}
        for _, entry in ipairs(THICKNESS_MENU_ORDER) do
            table.insert(sub_item_table, {
                text_func = function()
                    return entry.label .. ": " .. tostring(LINE_THICKNESS[entry.key]) .. "px"
                end,
                keep_menu_open = true,
                callback = function()
                    showThicknessPickerFromMenu(entry.key, entry.label)
                end,
            })
        end
        menu_items.fancy_highlight_thickness = {
            text = _("Highlight Style Thickness"),
            sorting_hint = "more_tools",
            sub_item_table = sub_item_table,
        }
    end

    local orig_ReaderUI_init = ReaderUI.init
    ReaderUI.init = function(self, ...)
        orig_ReaderUI_init(self, ...)
        if self.menu and self.menu.registerToMainMenu then
            self.menu:registerToMainMenu(ThicknessMenu)
            logger.info("[FancyHighlightStyles] Thickness menu registered.")
        else
            logger.warn("[FancyHighlightStyles] self.menu not available; thickness menu not registered.")
        end
    end
end)

if not ok_menu then
    require("logger").warn("[FancyHighlightStyles] Could not add Tools-menu thickness entry: ", menu_err)
end
