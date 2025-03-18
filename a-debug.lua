--[[
if not _G.charSelectExists return end

local function get_debug_enabled()
    return _G.charSelect.get_option(_G.charSelect.optionTableRef.debugInfo) ~= 0
end

local debugLines = {}
function add_debug_display(string)
    table.insert(debugLines, string)
end

function clear_debug()
    debugLines = {}
end

local function render_squishy_debug()
    if get_debug_enabled() then
        clear_debug()
        return
    end
    djui_hud_set_resolution(RESOLUTION_N64)
    for i = 1, #debugLines do
        djui_hud_print_text(debugLines[i], )
    end
end

hook_event(HOOK_ON_HUD_RENDER, render_squishy_debug)
]]