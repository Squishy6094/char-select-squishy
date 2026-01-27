if not _G.charSelectExists then return end

local OPTION_SQUISHY_DEBUG = _G.charSelect.add_option("Squishy Debugging", 0, 1, nil, {"Toggles Displaying Debug Info", "while playing as a", "[CS] Squishy Character"})

local function get_debug_enabled()
    return _G.charSelect.get_options_status(OPTION_SQUISHY_DEBUG) ~= 0
end

local debugLines = {"Squishy Debugging:"}
function add_debug_display(m, string)
    if m == nil then m = gMarioStates[0] end
    if m.playerIndex ~= 0 then return end
    table.insert(debugLines, string)
end

function debug_num_to_hex(num)
    if num == 0 then
        return '0'
    end
    local neg = false
    if num < 0 then
        neg = true
        num = num * -1
    end
    local hexstr = "0123456789ABCDEF"
    local result = ""
    while num > 0 do
        local n = (num%16)
        result = string.sub(hexstr, n + 1, n + 1) .. result
        num = math.floor(num / 16)
    end
    result = '0x'..result
    if neg then
        result = '-' .. result
    end
    return result
end

function debug_num_decimal_shorten(num)
    if num == 0 then
        return '0'
    end
    return tostring(math.floor(num*100)/100)
end

function clear_debug()
    debugLines = {"Squishy Debugging:"}
end

local x = 10
local y = 40
local scale = 0.3
local spacing = 9
local function render_squishy_debug()
    if not get_debug_enabled() or #debugLines <= 1 then
        clear_debug()
        return
    end
    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_color(0, 0, 0, 150)
    local measure = 0
    for i = 1, #debugLines do
        currMeasure = djui_hud_measure_text(debugLines[i])*scale
        if currMeasure > measure then
            measure = currMeasure
        end
    end
    djui_hud_render_rect(x, y, measure + 10, #debugLines*spacing + spacing*0.5)
    djui_hud_set_color(255, 255, 255, 255)
    for i = 1, #debugLines do
        djui_hud_print_text(debugLines[i], x + 3, y + 2 + (i-1)*spacing, scale)
    end
    clear_debug()
end

hook_event(HOOK_ON_HUD_RENDER, render_squishy_debug)