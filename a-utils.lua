-----------------
-- OMM Support --
-----------------

-- Moves
ACT_OMM_SPIN_GROUND = -1
ACT_OMM_SPIN_JUMP = -1
ACT_OMM_SPIN_POUND = -1
ACT_OMM_CAPPY_THROW_GROUND = -1
ACT_OMM_ROLL = -1
ACT_OMM_WALL_SLIDE = -1
ACT_OMM_MIDAIR_SPIN = -1
-- Settings
OMM_SETTING_MOVESET = ""
OMM_SETTING_CAMERA = ""
-- Settings Toggles
OMM_SETTING_MOVESET_ODYSSEY = -1
OMM_SETTING_CAMERA_ON = -1

if _G.OmmEnabled then
    ACT_OMM_SPIN_GROUND = _G.OmmApi["ACT_OMM_SPIN_GROUND"]
    ACT_OMM_SPIN_JUMP = _G.OmmApi["ACT_OMM_SPIN_JUMP"]
    ACT_OMM_SPIN_POUND = _G.OmmApi["ACT_OMM_SPIN_POUND"]
    ACT_OMM_CAPPY_THROW_GROUND = _G.OmmApi["ACT_OMM_CAPPY_THROW_GROUND"]
    ACT_OMM_ROLL = _G.OmmApi["ACT_OMM_ROLL"]
    ACT_OMM_WALL_SLIDE = _G.OmmApi["ACT_OMM_WALL_SLIDE"]
    OMM_SETTING_MOVESET =  _G.OmmApi["OMM_SETTING_MOVESET"]
    OMM_SETTING_MOVESET_ODYSSEY = _G.OmmApi["OMM_SETTING_MOVESET_ODYSSEY"]
    OMM_SETTING_CAMERA = _G.OmmApi["OMM_SETTING_CAMERA"]
    OMM_SETTING_CAMERA_ON = _G.OmmApi["OMM_SETTING_CAMERA_ON"]
    ACT_OMM_MIDAIR_SPIN = _G.OmmApi["ACT_OMM_MIDAIR_SPIN"]
end

--- @param m MarioState
function omm_moveset_enabled(m)
    if not _G.OmmEnabled then return false end
    if _G.OmmApi.omm_get_setting(m, OMM_SETTING_MOVESET) == OMM_SETTING_MOVESET_ODYSSEY then
        return true
    end
end

---------------------
-- Romhack Support --
---------------------

ROMHACK_NONE = 0
ROMHACK_UNKNOWN = 1
ROMHACK_SOMARI = 2

currRomhack = ROMHACK_NONE

for i in pairs(gActiveMods) do
    local mod = gActiveMods[i]
    local modTag = ""
    if mod.incompatible ~= nil then
        modTag = modTag .. " " .. mod.incompatible
    end
    if mod.category ~= nil then
        modTag = modTag .. " " .. mod.category
    end
    if modTag ~= "" then
        if modTag:find("romhack") then
            if mod.name:find("Somari") then
                currRomhack = ROMHACK_SOMARI
            else
                currRomhack = ROMHACK_UNKNOWN
            end
        end
    end
end

function network_is_romhack()
    return currRomhack ~= ROMHACK_NONE
end

function network_mario_is_in_area(index)
    if index == 0 then return true end
    local n0 = gNetworkPlayers[0]
    local np = gNetworkPlayers[index]
    if np.currAreaIndex ~= n0.currAreaIndex then return false end
    if np.currLevelNum ~= n0.currLevelNum then return false end
    if np.currActNum ~= n0.currActNum then return false end
    return true
end