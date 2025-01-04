local page = 1
local handbookPages = {
    {
        {t = "Character Select", x = 0.5, y = 0.1, s = 0.5},
        {t = "Squishy", x = 0.5, y = 0.17, s = 1.1, f = FONT_CUSTOM_HUD},
        {t = "Offical Handbook", x = 0.5, y = 0.35, s = 0.5},
        {t = "Author: Squishy6094", x = 0.5, y = 0.6, s = 0.4},
        {t = "This is some text", x = 0, y = 0.7, s = 0.4},
        {t = "Even more textt woagg o.o", x = 1, y = 0.8, s = 0.4},
    },
}

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