local page = 2
local handbookPages = {
    {
        {t = "Character Select", x = 0.5, y = 0.1, s = 0.5},
        {t = "Squishy", x = 0.5, y = 0.17, s = 1.1, f = FONT_CUSTOM_HUD},
        {t = "Offical Handbook", x = 0.5, y = 0.35, s = 0.5},
        {t = "Author: Squishy6094", x = 0.5, y = 0.6, s = 0.4},
    },
    {
        {t = "Ground Pound", x = 0, y = 0, s = 0.7, f = FONT_SPECIAL},
        {t = "A moves inspired by Pasta Castle,", x = 0, y = 0.15, s = 0.3},
        {t = "This move send your upwards before", x = 0, y = 0.20, s = 0.3},
        {t = "slamming into the ground, it can", x = 0, y = 0.25, s = 0.3},
        {t = "be canceled by pressing A midair", x = 0, y = 0.30, s = 0.3},
        {t = "and can be acted out of when", x = 0, y = 0.35, s = 0.3},
        {t = "landing by using A or B, which", x = 0, y = 0.40, s = 0.3},
        {t = "puts you in a Jump and Slide respectivly!", x = 0, y = 0.45, s = 0.3},
    },
}

for i = 1, #handbookPages do
    table.insert(handbookPages[i], {t = "Squishy Handbook", x = 0, y = 1, s = 0.3})
    table.insert(handbookPages[i], {t = tostring(i), x = 1, y = 1, s = 0.3})
end

local function hud_render()
    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_color(255, 255, 255, 255)
    local pagePadding = 10
    local pageWidth = 130
    local pageHeight = 180
    local pageX = djui_hud_get_screen_width()*0.5 - pageWidth*0.5
    local pageY = djui_hud_get_screen_height()*0.5 - pageHeight*0.5
    djui_hud_render_rect(pageX - pagePadding, pageY - pagePadding, pageWidth + pagePadding*2, pageHeight + pagePadding*2)
    djui_hud_set_color(0, 0, 0, 255)
    for i = 1, #handbookPages[page] do
        local textObj = handbookPages[page][i]
        djui_hud_set_font(textObj.f ~= nil and textObj.f or FONT_NORMAL)
        local text = textObj.t
        local scale = textObj.s
        local x = pageX + pageWidth*textObj.x - djui_hud_measure_text(text)*scale*textObj.x
        local y = pageY + pageHeight*textObj.y - 30*scale*textObj.y
        djui_hud_print_text(text, x, y, scale)
    end
end

--hook_event(HOOK_ON_HUD_RENDER, hud_render)