
-------------
-- Moveset --
-------------

gExtraStates = {}
for i = 0, MAX_PLAYERS - 1 do
    gExtraStates[i] = {
        forwardVelStore = 0,
        yVelStore = 0,
        groundPoundJump = true,
        groundPoundFromRollout = true,
        prevForwardVel = 0,
        intendedDYaw = 0,
        intendedMag = 0,
        sidewaysSpeed = 0,
        prevFloorDist = 0,
        prevWallAngle = 0,
        ommRolling = false,
        spamBurnout = 0,
    }
end

-- OMM Support
-- OMM Moves
local ACT_OMM_SPIN_JUMP = -1
local ACT_OMM_SPIN_POUND = -1
local ACT_OMM_SPIN_POUND_LAND = -1
local ACT_OMM_ROLL = -1
local ACT_OMM_WALL_SLIDE = -1
-- Settings
local OMM_SETTING_MOVESET = ""
-- Settings Toggles
local OMM_SETTING_MOVESET_ODYSSEY = -1
if _G.OmmEnabled then
    ACT_OMM_SPIN_JUMP = _G.OmmApi["ACT_OMM_SPIN_JUMP"]
    ACT_OMM_SPIN_POUND = _G.OmmApi["ACT_OMM_SPIN_POUND"]
    ACT_OMM_SPIN_POUND_LAND = _G.OmmApi["ACT_OMM_SPIN_POUND_LAND"]
    ACT_OMM_ROLL = _G.OmmApi["ACT_OMM_ROLL"]
    ACT_OMM_WALL_SLIDE = _G.OmmApi["ACT_OMM_WALL_SLIDE"]
    OMM_SETTING_MOVESET =  _G.OmmApi["OMM_SETTING_MOVESET"]
    OMM_SETTING_MOVESET_ODYSSEY = _G.OmmApi["OMM_SETTING_MOVESET_ODYSSEY"]
end


--- @param m MarioState
local function omm_moveset_enabled(m)
    if not _G.OmmEnabled then return false end
    if _G.OmmApi.omm_get_setting(m, OMM_SETTING_MOVESET) == OMM_SETTING_MOVESET_ODYSSEY then
        return true
    end
end

function get_mario_floor_steepness(m, angle)
    if angle == nil then angle = m.faceAngle.y end
    local floor = collision_find_surface_on_ray(m.pos.x, m.pos.y + 150, m.pos.z, 0, -300, 0).hitPos.y
    local floorInFront = collision_find_surface_on_ray(m.pos.x + sins(angle), m.pos.y + 150, m.pos.z + coss(angle), 0, -300, 0).hitPos.y
    local floorDif = floor - floorInFront 
    if floorDif > 20 or floorDif < -20 then floorDif = 0 end
    return floorDif
end

function get_mario_y_vel_from_floor(m)
    if m.pos.y == m.floorHeight then
        return math.sqrt(m.vel.x^2 + m.vel.y^2)*-get_mario_floor_steepness(m)
    else
        return m.vel.y
    end
end

local function set_mario_x_and_y_vel_from_floor_steepness(m, multiplier)
    if multiplier == nil then multiplier = 1 end
    local angle = m.floorAngle
    local floor = collision_find_surface_on_ray(m.pos.x, m.pos.y + 150, m.pos.z, 0, -300, 0).hitPos.y
    local floorInFront = collision_find_surface_on_ray(m.pos.x + sins(angle), m.pos.y + 150, m.pos.z + coss(angle), 0, -300, 0).hitPos.y
    local floorDif = floor - floorInFront 
    if floorDif > 20 or floorDif < -20 then floorDif = 0 end
    m.vel.x = m.vel.x + sins(angle)*floorDif*multiplier
    m.vel.z = m.vel.z + coss(angle)*floorDif*multiplier
end

local function clamp(num, min, max)
    return math.min(math.max(num, min), max)
end

local function clamp_soft(num, min, max, rate)
    if num < min then
        num = num + rate
    elseif num > min then
        num = num - rate
    end
    return num
end

local function set_mario_action_and_y_vel(m, action, arg, velY)
    m.vel.y = velY
    return set_mario_action(m, action, arg)
end

local function mario_is_on_water(m)
    if m.waterLevel == nil then return false end
    if m.pos.y > m.waterLevel + math.abs(m.forwardVel)*get_mario_floor_steepness(m) then return false end
    if m.waterLevel + math.abs(m.forwardVel)*get_mario_floor_steepness(m) < m.floorHeight + 60 then return false end
    return true
end

local function convert_s16(num)
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

ACT_SQUISHY_DIVE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_DIVING )
ACT_SQUISHY_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_BUTT_OR_STOMACH_SLIDE | ACT_FLAG_DIVING | ACT_FLAG_SHORT_HITBOX)
ACT_SQUISHY_SLIDE_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_AIR | ACT_FLAG_BUTT_OR_STOMACH_SLIDE | ACT_FLAG_DIVING | ACT_FLAG_SHORT_HITBOX)
ACT_SQUISHY_ROLLOUT = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_GROUND_POUND = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_GROUND_POUND_LAND = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
ACT_SQUISHY_GROUND_POUND_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR | ACT_FLAG_CONTROL_JUMP_HEIGHT)
ACT_SQUISHY_WALL_SLIDE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)
ACT_SQUISHY_WATER_POUND = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_SWIMMING_OR_FLYING)
ACT_SQUISHY_WATER_POUND_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_SWIMMING_OR_FLYING)
ACT_SQUISHY_FIRE_BURN = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)

--- @param m MarioState
local function act_squishy_dive(m)
    local e = gExtraStates[m.playerIndex]
    common_air_action_step(m, ACT_DIVE_SLIDE, CHAR_ANIM_DIVE, AIR_STEP_NONE)
    if m.actionTimer == 1 then
        mario_set_forward_vel(m, m.forwardVel + 15)
        --m.vel.y = 20
    end
    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_slide(m)
    local e = gExtraStates[m.playerIndex]
    e.forwardVelStore = math.min(e.forwardVelStore + get_mario_floor_steepness(m)*8, 130) - 0.25
    m.slideVelX = sins(m.faceAngle.y)*e.forwardVelStore
    m.slideVelZ = coss(m.faceAngle.y)*e.forwardVelStore
    e.yVelStore = get_mario_y_vel_from_floor(m)
    if mario_is_on_water(m) then
        m.pos.y = m.pos.y + 10
        set_mario_action_and_y_vel(m, ACT_SQUISHY_SLIDE_AIR, 0, 50)
    end
    common_slide_action_with_jump(m, ACT_SLIDE_KICK_SLIDE_STOP, ACT_DOUBLE_JUMP, ACT_SQUISHY_SLIDE_AIR, MARIO_ANIM_SLIDE_KICK)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x80, 0x80)
    if m.input & INPUT_A_PRESSED ~= 0 then
        if m.actionArg == 1 then
            set_mario_action(m, ACT_DOUBLE_JUMP, 0)
        else
            set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, 30)
        end
    end
    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_slide_air(m)
    local e = gExtraStates[m.playerIndex]
    common_air_action_step(m, ACT_SQUISHY_SLIDE, MARIO_ANIM_SLIDE_KICK, AIR_STEP_NONE)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0xF0, 0xF0)
    if m.actionTimer == 1 and m.prevAction == ACT_SQUISHY_SLIDE then
        m.vel.y = e.yVelStore
    end
    if m.actionArg == 0 then
        if e.forwardVelStore > 30 and mario_is_on_water(m) then
            set_mario_action_and_y_vel(m, ACT_SQUISHY_SLIDE_AIR, 0, e.forwardVelStore*0.25)
            e.forwardVelStore = e.forwardVelStore - 2
            m.particleFlags = PARTICLE_SHALLOW_WATER_SPLASH
            m.actionTimer = 0
            m.marioObj.header.gfx.angle.x = -0xB0*clamp(m.vel.y, -40, 40)
        end
    else
        --common_air_action_step(m, ACT_SQUISHY_GROUND_POUND_LAND, MARIO_ANIM_SLIDE_KICK, AIR_STEP_NONE)
        m.vel.y = -math.abs(e.forwardVelStore)
        m.marioObj.header.gfx.angle.x = 0x2000
        e.forwardVelStore = e.forwardVelStore + 3
    end
    m.peakHeight = m.pos.y
    m.forwardVel = e.forwardVelStore
    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_Z_DOWN ~= 0 then
        m.actionArg = 1
        if mario_is_on_water(m) then
            m.faceAngle.x = -0x2000
            set_mario_action(m, ACT_SQUISHY_WATER_POUND, 0)
        end
    end
    if m.input & INPUT_A_PRESSED ~= 0 or m.actionTimer > 45 then
        set_mario_action(m, ACT_SQUISHY_ROLLOUT, 0)
    end
end

--- @param m MarioState
local function act_squishy_rollout(m)
    local e = gExtraStates[m.playerIndex]
    if m.actionTimer == 0 then
        if m.forwardVel > 70 then
            play_character_sound(m, CHAR_SOUND_WHOA)
        else
            play_character_sound(m, CHAR_SOUND_PUNCH_WAH)
        end
        if m.actionArg ~= 0 then
            m.forwardVel = m.forwardVel*0.8
        end
    end
    --[[
    if m.actionTimer == 1 then
        set_mario_animation(m, MARIO_ANIM_FORWARD_SPINNING_FLIP)
        m.vel.y = 30 --+ -get_mario_floor_steepness(m)*10
        m.pos.y = m.pos.y + 1
    end
    ]]
    common_air_action_step(m, ACT_JUMP_LAND, MARIO_ANIM_FORWARD_SPINNING_FLIP, AIR_STEP_NONE)
    m.peakHeight = m.pos.y
    --m.vel.y = m.vel.y + 0.5
    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_Z_PRESSED ~= 0 and m.actionArg == 0 then
        set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 50)
    end
end

local poundSpinAnim = 0
--- @param m MarioState
local function act_squishy_ground_pound(m)
    local e = gExtraStates[m.playerIndex]
    local anim = MARIO_ANIM_GROUND_POUND
    if m.actionArg == 1 then
        anim = MARIO_ANIM_DIVE
    end
    if m.actionArg == 2 then
        anim = MARIO_ANIM_TWIRL
    end
    common_air_action_step(m, ACT_SQUISHY_GROUND_POUND_LAND, anim, AIR_STEP_NONE)
    -- setup when action starts (horizontal speed and voiceline)
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_WAH2)
        poundSpinAnim = 0
    end
    e.groundPoundFromRollout = true
    poundSpinAnim = poundSpinAnim + math.min(math.abs(m.vel.y), 100)
    m.marioObj.header.gfx.angle.y = m.faceAngle.y + poundSpinAnim*0x80
    if m.actionArg == 1 then
        m.marioObj.header.gfx.angle.x = 0x4000*clamp(-m.vel.y + 60, 0, 60)/50
    else
        if omm_moveset_enabled(m) and m.input & INPUT_B_PRESSED ~= 0 then
            m.faceAngle.y = m.intendedYaw
            set_mario_action_and_y_vel(m, ACT_SQUISHY_DIVE, 0, 30)
        end
    end
    if m.actionArg == 2 then -- OMM
        m.vel.x = 0
        m.vel.z = 0
        m.forwardVel = 0
        m.particleFlags = PARTICLE_SPARKLES
        --m.marioObj.header.gfx.angle.x = 0x4000*clamp(-m.vel.y + 60, 0, 60)/50
    end
    e.yVelStore = m.vel.y
    m.actionTimer = m.actionTimer + 1
    m.peakHeight = m.pos.y
    m.forwardVel = m.forwardVel*1.01
    if mario_is_on_water(m) then
        m.faceAngle.x = -0x4000
        set_mario_action(m, ACT_SQUISHY_WATER_POUND, 0)
    end
    if m.input & INPUT_A_PRESSED ~= 0 and m.input & INPUT_Z_DOWN == 0 then
        m.faceAngle.y = m.intendedYaw
        m.forwardVel = math.abs(m.forwardVel)
        set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 1, 30)
    end
end

--- @param m MarioState
local function act_squishy_ground_pound_gravity(m)
    m.vel.y = math.max(m.vel.y - 7, -200)
end

--- @param m MarioState
local function act_squishy_ground_pound_land(m)
    if mario_floor_is_slippery(m) ~= 1 then
        m.vel.x = 0
        m.vel.y = 0
        common_landing_action(m, MARIO_ANIM_GROUND_POUND_LANDING, ACT_FREEFALL)
    else
        m.faceAngle.y = m.floorAngle
        common_slide_action_with_jump(m, ACT_SQUISHY_SLIDE, ACT_SQUISHY_GROUND_POUND_JUMP, ACT_SQUISHY_ROLLOUT, MARIO_ANIM_GROUND_POUND_LANDING)
    end
    set_mario_animation(m, MARIO_ANIM_GROUND_POUND_LANDING)
    local e = gExtraStates[m.playerIndex]
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_HAHA)
        --play_mario_heavy_landing_sound(m)
        e.forwardVelStore = m.forwardVel
        m.particleFlags = PARTICLE_HORIZONTAL_STAR | PARTICLE_MIST_CIRCLE
    end
    
    m.forwardVel = 0

    m.actionTimer = m.actionTimer + 1
    if m.actionTimer > 10 then
        set_mario_action(m, ACT_IDLE, 0)
        e.groundPoundJump = true
    else
        if m.input & INPUT_A_PRESSED ~= 0 then
            if omm_moveset_enabled(m) and m.controller.buttonDown & Y_BUTTON ~= 0 then
                set_mario_action(m, ACT_OMM_SPIN_JUMP, 0)
            else
                if e.groundPoundJump then
                    m.faceAngle.y = m.intendedYaw
                    m.forwardVel = e.forwardVelStore + clamp(get_mario_floor_steepness(m)*50, -60, 60)
                    e.groundPoundJump = false
                    m.vel.y = math.max(70, math.abs(e.yVelStore*0.7))
                    set_mario_action(m, ACT_SQUISHY_GROUND_POUND_JUMP, 0)
                else
                    m.forwardVel = (e.forwardVelStore + clamp(get_mario_floor_steepness(m)*50, -60, 60))*0.7
                    m.vel.y = math.max(70, math.abs(e.yVelStore*0.6))
                    set_mario_action(m, ACT_SQUISHY_GROUND_POUND_JUMP, 0)
                end
            end
        end
        if (m.input & INPUT_B_PRESSED ~= 0) then
            m.faceAngle.y = m.intendedYaw
            e.forwardVelStore = math.max(math.abs(e.yVelStore), e.forwardVelStore)
            set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
            e.groundPoundJump = true
        end
    end
end

local poundJumpSpinAnim = 0
--- @param m MarioState
local function act_squishy_ground_pound_jump(m)
    common_air_action_step(m, ACT_JUMP_LAND, CHAR_ANIM_SINGLE_JUMP, AIR_STEP_NONE)
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_YAHOO_WAHA_YIPPEE)
        poundJumpSpinAnim = 0x20000
    end
    if poundJumpSpinAnim > 1 then
        poundJumpSpinAnim = poundJumpSpinAnim*0.8
        m.marioObj.header.gfx.angle.y = m.faceAngle.y + poundJumpSpinAnim
    end
    set_mario_particle_flags(m, PARTICLE_SPARKLES, 0)

    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_B_PRESSED ~= 0 then
        if m.forwardVel > 30 then
            set_mario_action(m, ACT_SQUISHY_DIVE, 0)
        else
            set_mario_action(m, ACT_JUMP_KICK, 0)
        end
    end
    if m.input & INPUT_Z_PRESSED ~= 0 then
        set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60)
    end
end

--- @param m MarioState
local function act_squishy_wall_slide(m)
    local e = gExtraStates[m.playerIndex]
    perform_air_step(m, AIR_STEP_NONE)
    set_mario_animation(m, MARIO_ANIM_START_WALLKICK)
    if m.actionTimer == 1 then 
        m.faceAngle.y = convert_s16(m.faceAngle.y + 0x8000)
    end
    m.vel.y = clamp(m.vel.y - 0.6, -70, 150)
    m.particleFlags = PARTICLE_DUST
    if m.wall == nil then
        if m.pos.y == m.floorHeight and e.prevFloorDist < 100 then
            m.faceAngle.y = convert_s16(e.prevWallAngle)
            set_mario_action(m, ACT_FREEFALL_LAND, 0)
        else
            m.faceAngle.y = convert_s16(e.prevWallAngle + 0x8000)
            set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, m.vel.y)
            m.pos.y = m.pos.y + 10
            m.forwardVel = m.forwardVel * 0.4
        end
    else
        e.prevFloorDist = m.pos.y - m.floorHeight
        e.prevWallAngle = convert_s16(atan2s(m.wall.normal.z, m.wall.normal.x))
    end
    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_A_PRESSED ~= 0 then
        set_mario_action_and_y_vel(m, ACT_WALL_KICK_AIR, 0, math.max(m.vel.y * 0.7, 30))
        m.forwardVel = m.forwardVel * 0.8
    end
end

local poundSwimAnim = 0
--- @param m MarioState
local function act_squishy_water_pound(m)
    local e = gExtraStates[m.playerIndex]
    perform_water_step(m)
    set_mario_animation(m, MARIO_ANIM_DIVE)

    if m.actionTimer == 0 then
        e.forwardVelStore = math.abs(m.vel.y*0.9)
        m.vel.x = 0
        m.vel.z = 0
    end

    if (m.area.terrainType & TERRAIN_MASK) == TERRAIN_SNOW then
        m.health = m.health - math.max(e.forwardVelStore/5, 3)
    else
        m.health = m.health - math.max(e.forwardVelStore/15, 1)
    end

    e.forwardVelStore = e.forwardVelStore - 1

    m.faceAngle.x = clamp(m.faceAngle.x + -m.controller.stickY*0x10, -0x3FF0, 0x3FF0)
    m.faceAngle.y = m.faceAngle.y + -m.controller.stickX*0x10
    m.forwardVel = e.forwardVelStore

    m.vel.x = m.forwardVel * sins(m.faceAngle.y) * coss(m.faceAngle.x)
    m.vel.y = m.forwardVel * sins(m.faceAngle.x)
    m.vel.z = m.forwardVel * coss(m.faceAngle.y) * coss(m.faceAngle.x)

    poundSwimAnim = poundSwimAnim + math.min(math.abs(e.forwardVelStore), 100)
    m.marioObj.header.gfx.angle.z = m.faceAngle.z + poundSwimAnim*0x80
    --m.marioObj.header.gfx.angle.y = m.faceAngle.y + 0x4000
    if m.vel.y < 0 and m.faceAngle.x < 0 and m.pos.y < m.floorHeight + 10 then
        m.faceAngle.x = -m.faceAngle.x
        m.vel.y = -m.vel.y
    end
    if e.forwardVelStore > 40 and m.pos.y >= m.waterLevel - 140 then
        m.pos.y = m.pos.y + 140
        e.forwardVelStore = e.forwardVelStore*0.7
        set_mario_action(m, ACT_SQUISHY_WATER_POUND_AIR, 0)
        set_camera_mode(m.area.camera, CAMERA_MODE_NONE, 0)
    end
    if e.forwardVelStore < 15 or m.input & INPUT_Z_DOWN == 0 then
        set_mario_action(m, ACT_WATER_IDLE, 0)
    end
    m.actionTimer = m.actionTimer + 1
end

local poundSwimAnim = 0
--- @param m MarioState
local function act_squishy_water_pound_air(m)
    local e = gExtraStates[m.playerIndex]
    common_air_action_step(m, ACT_FREEFALL_LAND, MARIO_ANIM_DIVE, AIR_STEP_NONE)
    set_mario_animation(m, MARIO_ANIM_DIVE)

    if m.actionTimer == 0 then
        e.forwardVelStore = math.abs(m.vel.y)
        m.vel.y = math.max(m.forwardVel * sins(m.faceAngle.x) * 0.5, 30)
    end

    m.vel.y = m.vel.y - 2
    --m.faceAngle.x = clamp(m.faceAngle.x + -m.controller.stickY*0x10, -0x3FF0, 0x3FF0)
    m.faceAngle.y = m.faceAngle.y + -m.controller.stickX*0x10
    m.forwardVel = e.forwardVelStore

    m.vel.x = m.forwardVel * sins(m.faceAngle.y) * coss(m.faceAngle.x)
    m.vel.z = m.forwardVel * coss(m.faceAngle.y) * coss(m.faceAngle.x)

    poundSwimAnim = poundSwimAnim + math.min(math.abs(e.forwardVelStore*0.8), 100)
    m.marioObj.header.gfx.angle.z = m.faceAngle.z + poundSwimAnim*0x80
    m.marioObj.header.gfx.angle.x = m.faceAngle.x - 0x4000 - m.vel.y*0x80

    if m.pos.y <= m.waterLevel then
        m.faceAngle.x = -0x3000
        e.forwardVelStore = e.forwardVelStore*2
        set_mario_action(m, ACT_SQUISHY_WATER_POUND, 0)
    end
    if m.input & INPUT_Z_DOWN == 0 then
        set_mario_action(m, ACT_FREEFALL, 0)
    end
    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_water_pound_air_gravity(m)
    m.vel.y = math.max(m.vel.y - 4, -200)
end

--- @param m MarioState
local function act_squishy_fire_burn(m)
    local e = gExtraStates[m.playerIndex]
    common_air_action_step(m, ACT_SQUISHY_FIRE_BURN, MARIO_ANIM_FIRE_LAVA_BURN, AIR_STEP_NONE)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x300, 0x300)
    
    if m.pos.y == m.floorHeight and m.vel.y < 50 then
        m.vel.y = 50
    end
    
    if e.spamBurnout <= 0 then
        set_mario_action(m, ACT_FREEFALL, 0)
    end

    m.actionTimer = m.actionTimer + 1
end

hook_mario_action(ACT_SQUISHY_DIVE, { every_frame = act_squishy_dive}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_SLIDE, { every_frame = act_squishy_slide}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_SLIDE_AIR, { every_frame = act_squishy_slide_air})
hook_mario_action(ACT_SQUISHY_ROLLOUT, act_squishy_rollout)
hook_mario_action(ACT_SQUISHY_GROUND_POUND, { every_frame = act_squishy_ground_pound, gravity = act_squishy_ground_pound_gravity}, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_GROUND_POUND_JUMP, { every_frame = act_squishy_ground_pound_jump})
hook_mario_action(ACT_SQUISHY_GROUND_POUND_LAND, act_squishy_ground_pound_land, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_WALL_SLIDE, {every_frame = act_squishy_wall_slide})
hook_mario_action(ACT_SQUISHY_WATER_POUND, {every_frame = act_squishy_water_pound})
hook_mario_action(ACT_SQUISHY_WATER_POUND_AIR, {every_frame = act_squishy_water_pound_air, gravity = act_squishy_water_pound_air_gravity})
hook_mario_action(ACT_SQUISHY_FIRE_BURN, {every_frame = act_squishy_fire_burn})

local function squishy_update(m)
    local e = gExtraStates[m.playerIndex]
    if (m.action == ACT_LONG_JUMP or m.action == ACT_SQUISHY_DIVE) and m.input & INPUT_Z_PRESSED ~= 0 then
        set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, (m.action == ACT_SQUISHY_DIVE and 1 or 0), 60)
    end
    if m.action == ACT_BUTT_SLIDE then
        e.forwardVelStore = m.forwardVel
        set_mario_action(m, ACT_SQUISHY_SLIDE, 1)
    end
    if m.action == ACT_SLIDE_KICK then
        e.forwardVelStore = m.forwardVel + 30
        set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end
    if (m.action == ACT_PUNCHING or m.action == ACT_MOVE_PUNCHING) and m.actionArg == 9 then
        m.forwardVel = 70
        e.forwardVelStore = 70
        set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end
    if m.pos.y == m.floorHeight and m.action ~= ACT_SQUISHY_GROUND_POUND_LAND and m.action ~= ACT_SQUISHY_GROUND_POUND_JUMP then
        e.groundPoundJump = true
    end
    if m.action == ACT_SPAWN_SPIN_AIRBORNE and m.waterLevel > m.floorHeight then
        set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 1)
    end
    if e.spamBurnout > 0 then
        m.particleFlags = PARTICLE_FIRE
        m.health = m.health - 10
        play_sound(SOUND_AIR_BLOW_FIRE, m.pos)
        if (m.input & INPUT_A_PRESSED ~= 0 or m.input & INPUT_B_PRESSED ~= 0 or m.input & INPUT_Z_PRESSED ~= 0) then
            e.spamBurnout = e.spamBurnout - 1
            play_sound(SOUND_GENERAL_FLAME_OUT, m.pos)
        end
        if m.health < 255 then
            set_mario_action_and_y_vel(m, ACT_LAVA_BOOST, 0, m.vel.y)
            e.spamBurnout = 0
        end
        if (m.waterLevel ~= nil and m.pos.y < m.waterLevel) then
            play_sound(SOUND_GENERAL_FLAME_OUT, m.pos)
            e.spamBurnout = 0
        end
    end
    if omm_moveset_enabled(m) then
        if m.input & INPUT_Z_PRESSED ~= 0 then
            if m.action == ACT_SQUISHY_SLIDE and m.actionTimer > 3 then
                set_mario_action(m, ACT_OMM_ROLL, 0)
            end
            if m.action == ACT_OMM_ROLL and m.actionTimer > 3 then
                e.forwardVelStore = m.forwardVel
                set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
            end
        end
        e.ommRolling = (m.action == ACT_SQUISHY_SLIDE or m.action == ACT_OMM_ROLL)
    end
end

---@param m MarioState
local function squishy_before_action(m, nextAct)
    local e = gExtraStates[m.playerIndex]
    if nextAct == ACT_GROUND_POUND then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60)
    end
    if nextAct == ACT_DIVE then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0)
    end
    if nextAct == ACT_FORWARD_ROLLOUT then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, 30)
    end
    if nextAct == ACT_AIR_HIT_WALL or nextAct == ACT_OMM_WALL_SLIDE then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_WALL_SLIDE, 0, m.forwardVel + math.max(m.vel.y*0.7, 0))
    end
    if (nextAct == ACT_BURNING_FALL or nextAct == ACT_BURNING_GROUND or nextAct == ACT_BURNING_JUMP or nextAct == ACT_LAVA_BOOST) and m.health > 255 then
        e.spamBurnout = 15
        m.hurtCounter = 0
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_FIRE_BURN, 0, 90)
    end
    if omm_moveset_enabled(m) then
        if nextAct == ACT_OMM_SPIN_POUND then
            return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 2, -70)
        end
    end
end

local strainingBlacklist = {
    [ACT_FALLING_EXIT_AIRBORNE] = true,
    [ACT_EXIT_AIRBORNE] = true,
    [ACT_SPECIAL_EXIT_AIRBORNE] = true,
    [ACT_SPECIAL_DEATH_EXIT] = true,
    [ACT_DEATH_EXIT] = true,
    [ACT_SPAWN_NO_SPIN_AIRBORNE] = true,
    [ACT_SPAWN_SPIN_AIRBORNE] = true,
    [ACT_WATER_JUMP] = true,
    [ACT_FALL_AFTER_STAR_GRAB] = true,
    
    --[ACT_SQUISHY_CEILING_STICK] = true,
    [ACT_SQUISHY_WALL_SLIDE] = true,
    [ACT_SQUISHY_SLIDE_AIR] = true,
}

local canWallkick = {
    [ACT_JUMP] = ACT_JUMP,
    [ACT_HOLD_JUMP] = ACT_HOLD_JUMP,
    [ACT_DOUBLE_JUMP] = ACT_DOUBLE_JUMP,
    [ACT_TRIPLE_JUMP] = ACT_TRIPLE_JUMP,
    [ACT_SIDE_FLIP] = ACT_SIDE_FLIP,
    [ACT_BACKFLIP] = ACT_BACKFLIP,
    [ACT_LONG_JUMP] = ACT_LONG_JUMP,
    [ACT_WALL_KICK_AIR] = ACT_WALL_KICK_AIR,
    [ACT_TOP_OF_POLE_JUMP] = ACT_TOP_OF_POLE_JUMP,
    [ACT_FREEFALL] = ACT_FREEFALL,
    
    [ACT_SQUISHY_DIVE] = ACT_SQUISHY_DIVE,
    [ACT_SQUISHY_GROUND_POUND] = ACT_SQUISHY_GROUND_POUND,
    [ACT_SQUISHY_GROUND_POUND_JUMP] = ACT_SQUISHY_GROUND_POUND_JUMP,
    [ACT_SQUISHY_ROLLOUT] = ACT_SQUISHY_ROLLOUT,
}

local wallAngleLimit = 50
local function squishy_before_phys_step(m)
    local e = gExtraStates[m.playerIndex]

    -- Straining
    if not strainingBlacklist[m.action] and m.action & ACT_FLAG_SWIMMING_OR_FLYING == 0 and m.pos.y > m.floorHeight then
        if m.input & INPUT_NONZERO_ANALOG ~= 0 then
            e.intendedDYaw = m.intendedYaw - m.faceAngle.y
            e.intendedMag = m.intendedMag / 32;
            e.sidewaysSpeed = e.intendedMag * sins(e.intendedDYaw) * m.forwardVel*0.22
        end
        m.vel.x = m.vel.x + e.sidewaysSpeed * sins(m.faceAngle.y + 0x4000);
        m.vel.z = m.vel.z + e.sidewaysSpeed * coss(m.faceAngle.y + 0x4000);
    end

    -- Wider Wallslide angle
    if m.wall ~= nil then
        if (m.wall.type == SURFACE_BURNING) then return end

        local wallDYaw = (atan2s(m.wall.normal.z, m.wall.normal.x) - (m.faceAngle.y))
        --I don't really understand this however I do know the lower `limit` becomes, the more possible wallkick degrees.
        local limitNegative = (-((180 - wallAngleLimit) * (8192/45))) + 1
        local limitPositive = ((180 - wallAngleLimit) * (8192/45)) - 1
        --wallDYaw is s16, so I converted it
        wallDYaw = convert_s16(wallDYaw)

        --Standard air hit wall requirements
        if (m.forwardVel >= 16) and (canWallkick[m.action] ~= nil) then
            if (wallDYaw >= limitPositive) or (wallDYaw <= limitNegative) then
                mario_bonk_reflection(m, 0)
                m.faceAngle.y = m.faceAngle.y + 0x8000
                set_mario_action(m, ACT_AIR_HIT_WALL, 0)
            end
        end
    end

    if not omm_moveset_enabled(m) then
        -- Peaking Velocity
        if m.forwardVel > 70 then
            m.forwardVel = clamp_soft(m.forwardVel, -70, 70, 0.25)
        end
        -- Terminal Velocity
        m.forwardVel = math.min(m.forwardVel, 150)
    end
end

local function hud_render()
    local m = gMarioStates[0]
    local e = gExtraStates[0]
    djui_hud_set_resolution(RESOLUTION_N64)
    local burning = e.spamBurnout/15
    if burning > 0 then
        djui_hud_set_color(0, 0, 0, 200)
        djui_hud_render_rect(16, 30, 6, 25)
        djui_hud_set_color(255, 20, 0, 255)
        djui_hud_render_rect(17, 31, 4, 23*burning)
    end
end

local function on_character_select_load()
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_MARIO_UPDATE, squishy_update)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_SET_MARIO_ACTION, squishy_before_action)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_PHYS_STEP, squishy_before_phys_step)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ON_HUD_RENDER_BEHIND, hud_render)
end
hook_event(HOOK_ON_MODS_LOADED, on_character_select_load)