-----------------
-- OMM Support --
-----------------

-- Moves
ACT_OMM_SPIN_JUMP = -1
ACT_OMM_SPIN_POUND = -1
ACT_OMM_CAPPY_THROW_GROUND = -1
ACT_OMM_ROLL = -1
ACT_OMM_WALL_SLIDE = -1
-- Settings
OMM_SETTING_MOVESET = ""
-- Settings Toggles
OMM_SETTING_MOVESET_ODYSSEY = -1
if _G.OmmApi ~= nil then
    ACT_OMM_SPIN_JUMP = _G.OmmApi["ACT_OMM_SPIN_JUMP"]
    ACT_OMM_SPIN_POUND = _G.OmmApi["ACT_OMM_SPIN_POUND"]
    ACT_OMM_CAPPY_THROW_GROUND = _G.OmmApi["ACT_OMM_CAPPY_THROW_GROUND"]
    ACT_OMM_ROLL = _G.OmmApi["ACT_OMM_ROLL"]
    ACT_OMM_WALL_SLIDE = _G.OmmApi["ACT_OMM_WALL_SLIDE"]
    OMM_SETTING_MOVESET =  _G.OmmApi["OMM_SETTING_MOVESET"]
    OMM_SETTING_MOVESET_ODYSSEY = _G.OmmApi["OMM_SETTING_MOVESET_ODYSSEY"]
end

--- @param m MarioState
function omm_moveset_enabled(m)
    if not _G.OmmEnabled then return false end
    if _G.OmmApi.omm_get_setting(m, OMM_SETTING_MOVESET) == OMM_SETTING_MOVESET_ODYSSEY then
        return true
    end
end