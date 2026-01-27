if not _G.charSelectExists then return end

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

---------------
-- Functions --
---------------

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

table.copy = function(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end


function clamp(num, min, max)
    return math.min(math.max(num, min), max)
end

function clamp_soft(num, min, max, rate)
    if num < min then
        num = num + rate
        num = math.min(num, max)
    elseif num > max then
        num = num - rate
        num = math.max(num, min)
    end
    return num
end

function lerpS16Angle(a, b, t)
    a = math.s16(a)
    b = math.s16(b)

    local delta = b - a

    if delta > 0x8000 then
        delta = delta - 0x10000
    elseif delta < -0x8000 then
        delta = delta + 0x10000
    end

    return math.s16(a + delta * t)
end


function invlerp(x, a, b)
    return clamp((x - a) / (b - a), 0.0, 1.0)
end

function convert_s16(num)
    local min = -32768
    local max = 32767
    while (num < min) do
        num = max + (num - min)
    end
    while (num > max) do
        num = min + (num - max)
    end
    return num
end

function vec3f_angle_between(a, b)
    return math.acos(vec3f_dot(a, b) / (vec3f_length(a) * vec3f_length(b)))
end

function vec3f_non_nan(v)
    if v.x ~= v.x then v.x = 0 end
    if v.y ~= v.y then v.y = 0 end
    if v.z ~= v.z then v.z = 0 end
end

---------------------
-- Mario Functions --
---------------------

function set_mario_particle_flag(m, particle)
    if not network_mario_is_in_area(m.playerIndex) then return end
    m.particleFlags = m.particleFlags | particle
end

function set_mario_action_and_y_vel(m, action, arg, velY)
    m.vel.y = velY or 0
    return set_mario_action(m, action, arg)
end

function mario_is_on_water(m)
    if m.waterLevel == nil then return false end
    if m.pos.y > m.waterLevel + math.abs(m.forwardVel)*get_mario_slope_steepness(m) then return false end
    if m.waterLevel + math.abs(m.forwardVel)*get_mario_slope_steepness(m) < m.floorHeight + 60 then return false end
    return true
end

function get_mario_slope_steepness(m)
    local floor = m.floor
    local slopeAngle = atan2s(floor.normal.z, floor.normal.x)
    local angle = math.sqrt(floor.normal.x ^ 2 + floor.normal.z ^ 2)
    if math.abs(math.s16(m.faceAngle.y - slopeAngle)) > 0x4000 then
        angle = angle * -1.0
    end
    return angle
end

---@param m MarioState
---@param e table ExtraState
function mario_detatch_from_floor(m, e, airAction)
    if airAction == nil then airAction = ACT_FREEFALL end

    local speed = m.forwardVel
    add_debug_display(m, "Slope: " .. tostring(m.forwardVel))

    if e.floorSteep == nil then
        e.floorSteep = get_mario_slope_steepness(m)
    end

    local prevSlope = e.floorSteep
    local slope = get_mario_slope_steepness(m)
    local slopeDif = math.abs(prevSlope - slope)

    e.floorSteep = slope

    add_debug_display(m, "Slope: " .. tostring(slope))
    add_debug_display(m, "Prev. Slope: " .. tostring(prevSlope))

    -- DETACH: sudden slope change
    local velY = m.forwardVel * -prevSlope
    local velF = m.forwardVel * (1 - math.abs(prevSlope)*0.5)
    local velAngle = -coss(atan2s(velY, velF))
    if (slopeDif > 0.3 and (velAngle < slope - 0.2 or velAngle > slope + 0.2) and prevSlope < 0) or (m.pos.y > m.floorHeight + 10) then
        djui_chat_message_create(tostring(slopeDif))
        djui_chat_message_create(tostring(prevSlope))
        djui_chat_message_create(tostring(velAngle))
        m.vel.y = velY
        m.forwardVel = velF
        e.floorSteep = nil
        return set_mario_action(m, airAction, 0)
    end

    return 0
end
