
-- register the level here
LEVEL_SQUISHY_TUTORIAL = 0xFA
level_register('level_squishy_tutorial_entry', COURSE_NONE, 'Squishy Tutorial', 'level_squishy_tutorial_entry', 28000, 0x08, 0x08, 0x08)
local lvl_squishy_tutorial = smlua_level_util_get_info_from_short_name('level_squishy_tutorial_entry')
lvl_squishy_tutorial.levelNum = LEVEL_SQUISHY_TUTORIAL
--E_MODEL_MCDONALDCRATE = smlua_model_util_get_id("mcd_crate_geo")

function tutorial_init()
    local p = gNetworkPlayers[0]
    if p.currLevelNum == LEVEL_SQUISHY_TUTORIAL then
        area_get_warp_node(0x00).node.destLevel = gLevelValues.entryLevel
    end
end

function tutorial_warp()
    if gNetworkPlayers[0] then
        warp_to_level(LEVEL_SQUISHY_TUTORIAL, 1, 0)
        return true
    end
end

hook_event(HOOK_ON_LEVEL_INIT, tutorial_init)
hook_chat_command("squishy-tutorial", "Warps you to Squishy Tutorial", tutorial_warp)