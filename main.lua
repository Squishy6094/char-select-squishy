-- name: [CS] Squishy
-- description: new and reall
-- category: cs

if not _G.charSelectExists then
    local noCSMessages = {
        {
            name = "\\#008800\\Squishy",
            {text = "Hey turn on Character Select stupid!!", timer = 5.2*30},
            {text = "OOOoooohhhhh you want to turn on character selecttt ooooohhh,,", timer = 7.8*30},
            {text = "Wha,, where's my character selectt?", timer = 4.6*30},
            {text = "OWWWW FUCKKK AUGHH IT HURTSSS!!! I NEED MY API!! OWWWWWWW!!!!", timer = 9.1*30},
        },
        {
            name = "\\#3f48cc\\Trashcam",
            {text = "Hey man I think ya need some of that character select, if not you a #####.", timer = 11.5*30},
        },
        {
            name = "\\#2b0013\\Fłorałys",
            {text = "really now..?", timer = 3},
            {text = "hii don't mind me you can't find me anyway", timer = 3},
            {text = "skill issue", timer = 3},
            {text = "you're silly", timer = 3},
            {text = "floralys mussolini is on her way.", timer = 3},
        },
    }
    local frameCount = 0
    local rngPerson = (math.random(1, 3) == 3 and math.random(2, #noCSMessages) or 1)
    local rngMessage = math.random(1, #noCSMessages[rngPerson])
    local name = noCSMessages[rngPerson].name
    local message = noCSMessages[rngPerson][rngMessage].text
    local sendTime = noCSMessages[rngPerson][rngMessage].timer + math.random(-30, 30)
    hook_event(HOOK_UPDATE, function ()
        frameCount = frameCount + 1
        if frameCount == sendTime then
            djui_chat_message_create(name.."\\#dcdcdc\\: "..message)
            play_sound(SOUND_MENU_MESSAGE_APPEAR, gLakituState.curPos)
        end
    end)
    return 0
end

local E_MODEL_SQUISHY = smlua_model_util_get_id("squishy_geo")

local PALETTE_SQUISHY = {
    [SHOES] = "1C1C1C",
    [GLOVES] = "BFC72F",
    [EMBLEM] = "FFFFFF",
    [HAIR] = "130D0A",
    [SKIN] = "FBE7B7",
    [SHIRT] = "12250B",
    [PANTS] = "0B0E20",
}

local CT_SQUISHY = _G.charSelect.character_add("Squishy", {"Creator of Character Select!!", "Transgender ladyy full of", "coderinggg"}, "Squishy / SprSn64", "005500", E_MODEL_SQUISHY, CT_MARIO, "S", 1, 37)
_G.charSelect.character_add_palette_preset(E_MODEL_SQUISHY, PALETTE_SQUISHY)

local MOD_NAME = "Squishy Pack"
_G.charSelect.credit_add(MOD_NAME, "Squishy6094", "Coderingg :3")
_G.charSelect.credit_add(MOD_NAME, "SprSn64", "Models")
_G.charSelect.credit_add(MOD_NAME, "Shell_x33", "Textures / Prettyy >//<")

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
    }
end

local function get_mario_floor_steepness(m, angle)
    if angle == nil then angle = m.faceAngle.y end
    local floor = collision_find_surface_on_ray(m.pos.x, m.pos.y + 150, m.pos.z, 0, -300, 0).hitPos.y
    local floorInFront = collision_find_surface_on_ray(m.pos.x + sins(angle), m.pos.y + 150, m.pos.z + coss(angle), 0, -300, 0).hitPos.y
    local floorDif = floor - floorInFront 
    if floorDif > 20 or floorDif < -20 then floorDif = 0 end
    return floorDif
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

-- Functions and Constants
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

local ACT_SQUISHY_DIVE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
local ACT_SQUISHY_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_BUTT_OR_STOMACH_SLIDE)
local ACT_SQUISHY_ROLLOUT = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_ATTACKING )
local ACT_SQUISHY_GROUND_POUND = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
local ACT_SQUISHY_GROUND_POUND_LAND = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
local ACT_SQUISHY_GROUND_POUND_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)
--local ACT_SQUISHY_CEILING_STICK = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)
--local ACT_SQUISHY_CEILING_FLIP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)
local ACT_SQUISHY_WALL_SLIDE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)

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
    --djui_chat_message_create("FloorDif: "..get_mario_floor_steepness(m))
    e.forwardVelStore = math.min(e.forwardVelStore + get_mario_floor_steepness(m)*8, 130) - 0.25
    m.slideVelX = sins(m.faceAngle.y)*e.forwardVelStore
    m.slideVelZ = coss(m.faceAngle.y)*e.forwardVelStore
    if m.waterLevel ~= nil and m.pos.y <= m.waterLevel + 30 then
        djui_chat_message_create("HELPPP")
        m.vel.y = 50
    end
    common_slide_action_with_jump(m, ACT_SLIDE_KICK_SLIDE_STOP, ACT_DOUBLE_JUMP, ACT_SQUISHY_ROLLOUT, MARIO_ANIM_SLIDE_KICK)
    local rotSpeed = 0x80
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, rotSpeed, rotSpeed)
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
    common_air_action_step(m, ACT_SQUISHY_GROUND_POUND_LAND, anim, AIR_STEP_NONE)
    -- setup when action starts (horizontal speed and voiceline)
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_WAH2)
        poundSpinAnim = 0
    end
    e.groundPoundFromRollout = true
    poundSpinAnim = poundSpinAnim + math.abs(m.vel.y)
    m.marioObj.header.gfx.angle.y = m.faceAngle.y + poundSpinAnim*0x80
    if m.actionArg == 1 then
        m.marioObj.header.gfx.angle.x = 0x4000*clamp(-m.vel.y + 60, 0, 60)/50
    end
    e.yVelStore = m.vel.y
    m.actionTimer = m.actionTimer + 1
    m.peakHeight = m.pos.y
    m.forwardVel = m.forwardVel*1.01
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
    --common_landing_action(m, MARIO_ANIM_GROUND_POUND_LANDING, ACT_SQUISHY_GROUND_POUND)
    if mario_floor_is_slippery(m) ~= 1 then
        perform_ground_step(m)
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
    if m.actionTimer > 5 then
        set_mario_action(m, ACT_IDLE, 0)
        e.groundPoundJump = true
    else
        if m.input & INPUT_A_PRESSED ~= 0 then
            if e.groundPoundJump then
                m.faceAngle.y = m.intendedYaw
                m.forwardVel = e.forwardVelStore + clamp(get_mario_floor_steepness(m)*50, -60, 60)
                --set_mario_x_and_y_vel_from_floor_steepness(m, 1000)
                e.groundPoundJump = false
                set_mario_y_vel_based_on_fspeed(m, 50, 0.2)
                set_mario_action(m, ACT_SQUISHY_GROUND_POUND_JUMP, 0)
            else
                m.forwardVel = (e.forwardVelStore + clamp(get_mario_floor_steepness(m)*50, -60, 60))*0.7
                set_mario_y_vel_based_on_fspeed(m, 30, 0.2)
                set_mario_action(m, ACT_SQUISHY_ROLLOUT, 1)
            end
        end
        if (m.input & INPUT_B_PRESSED ~= 0) then
            m.faceAngle.y = m.intendedYaw
            e.forwardVelStore = math.max(math.abs(e.yVelStore*0.8), m.forwardVel)
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
--[[
--- @param m MarioState
local function act_squishy_ceiling_stick(m)
    local e = gExtraStates[m.playerIndex]
    perform_air_step(m, AIR_STEP_NONE)
    mario_set_forward_vel(m, 0)
    if m.actionTimer == 1 then
        set_mario_anim_with_accel(m, MARIO_ANIM_START_CROUCHING, 0x30000)
    elseif is_anim_past_end(m) ~= 0 then
        set_mario_animation(m, MARIO_ANIM_CROUCHING)
    end
    m.marioObj.header.gfx.angle.x = 0x8000
    m.marioObj.header.gfx.angle.y = m.faceAngle.y + 0x8000
    m.marioObj.header.gfx.pos.y = math.min(m.pos.y + m.marioObj.hitboxHeight, m.pos.y + e.yVelStore*(m.actionTimer+3))
    m.vel.x = 0
    m.vel.z = 0
    m.actionTimer = m.actionTimer + 1
    if m.actionTimer > 30 then
        set_mario_action(m, ACT_FREEFALL, 0)
    else
        if m.input & INPUT_A_PRESSED ~= 0 then
            --common_air_action_step(m, ACT_FREEFALL_LAND, MARIO_ANIM_CROUCHING, AIR_STEP_NONE)
            mario_set_forward_vel(m, e.forwardVelStore + 10)
            set_mario_action_and_y_vel(m, ACT_SQUISHY_CEILING_FLIP, 0, math.min(-20, -m.vel.y*0.7))
        end
    end
end


local function act_squishy_ceiling_stick_gravity(m)
    m.vel.y = 0
end
]]

--[[
--- @param m MarioState
local function act_squishy_ceiling_flip(m)
    common_air_action_step(m, ACT_FREEFALL_LAND, CHAR_ANIM_BACKWARD_SPINNING, AIR_STEP_NONE)
    m.marioObj.header.gfx.angle.x = 0x8000
    m.marioObj.header.gfx.pos.y = m.pos.y + m.marioObj.hitboxHeight
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_PUNCH_HOO)
        m.particleFlags = PARTICLE_TRIANGLE
    end
    m.actionTimer = m.actionTimer + 1
end
]]

--- @param m MarioState
local function act_squishy_wall_slide(m)
    perform_air_step(m, AIR_STEP_NONE)
    set_mario_animation(m, MARIO_ANIM_START_WALLKICK)
    if m.actionTimer == 1 then 
        m.faceAngle.y = convert_s16(m.faceAngle.y + 0x8000)
    end
    m.vel.y = clamp(m.vel.y - 0.6, -70, 150)
    m.particleFlags = PARTICLE_DUST
    if m.wall == nil then
        if m.pos.y <= m.floorHeight then
            set_mario_action(m, ACT_FREEFALL_LAND, 0)
        else
            m.faceAngle.y = convert_s16(m.faceAngle.y + 0x8000)
            set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, m.vel.y*0.8)
        end
    end
    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_A_PRESSED ~= 0 then
        set_mario_action_and_y_vel(m, ACT_WALL_KICK_AIR, 0, math.max(m.vel.y * 0.7, 30))
        m.vel.y = m.vel.y * 0.7
    end
end

hook_mario_action(ACT_SQUISHY_DIVE, { every_frame = act_squishy_dive}, INT_ANY_ATTACK)
hook_mario_action(ACT_SQUISHY_SLIDE, { every_frame = act_squishy_slide}, INT_ATTACK_SLIDE)
hook_mario_action(ACT_SQUISHY_ROLLOUT, act_squishy_rollout, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_GROUND_POUND, { every_frame = act_squishy_ground_pound, gravity = act_squishy_ground_pound_gravity}, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_GROUND_POUND_JUMP, { every_frame = act_squishy_ground_pound_jump})
hook_mario_action(ACT_SQUISHY_GROUND_POUND_LAND, act_squishy_ground_pound_land, INT_GROUND_POUND)
--hook_mario_action(ACT_SQUISHY_CEILING_STICK, {every_frame = act_squishy_ceiling_stick, gravity = act_squishy_ceiling_stick_gravity}, 0)
--hook_mario_action(ACT_SQUISHY_CEILING_FLIP, act_squishy_ceiling_flip, 0)
hook_mario_action(ACT_SQUISHY_WALL_SLIDE, {every_frame = act_squishy_wall_slide}, 0)

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
    --[[
    if m.input & INPUT_A_DOWN ~= 0 then
        if m.pos.y > find_floor_height(m.pos.x, m.pos.y, m.pos.z) and m.pos.y + m.marioObj.hitboxHeight + m.vel.y > find_ceil_height(m.pos.x + m.vel.x, m.pos.y, m.pos.z + m.vel.z) then
            e.forwardVelStore = m.forwardVel
            e.yVelStore = math.abs(m.vel.y)
            set_mario_action(m, ACT_SQUISHY_CEILING_FLIP, 0)
        end
    end
    ]]
end

---@param m MarioState
local function squishy_before_action(m, nextAct)
    if m.playerIndex == 0 then
        --djui_chat_message_create(tostring(gExtraStates[0].forwardVelStore))
    end
    if nextAct == ACT_GROUND_POUND then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60)
    end
    if nextAct == ACT_DIVE then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0)
    end
    if nextAct == ACT_FORWARD_ROLLOUT then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, 30)
    end
    if nextAct == ACT_AIR_HIT_WALL then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_WALL_SLIDE, 0, m.forwardVel + math.max(m.vel.y*0.7, 0))
    end
end

local forwardVelActs = {
    [ACT_WALKING] = true,
    [ACT_LONG_JUMP] = true,
    [ACT_CROUCH_SLIDE] = true,
}

local strainingBlacklist = {
    --[ACT_SQUISHY_CEILING_STICK] = true,
    [ACT_SQUISHY_WALL_SLIDE] = true,
    [ACT_FALLING_EXIT_AIRBORNE] = true,
    [ACT_EXIT_AIRBORNE] = true,
    [ACT_SPECIAL_EXIT_AIRBORNE] = true,
    [ACT_SPECIAL_DEATH_EXIT] = true,
    [ACT_DEATH_EXIT] = true,
    [ACT_SPAWN_NO_SPIN_AIRBORNE] = true,
    [ACT_SPAWN_SPIN_AIRBORNE] = true,
}

local function squishy_before_phys_step(m)
    local e = gExtraStates[m.playerIndex]
    --[[
    if forwardVelActs[m.action] and analog_stick_held_back(m) ~= 0 then
        e.prevForwardVel = math.max(m.forwardVel, e.prevForwardVel - 5)
        mario_set_forward_vel(m, e.prevForwardVel)
    else
        e.prevForwardVel = m.forwardVel
    end
    ]]
    --(m.intendedMag < convert_s16(m.faceAngle + 0x4000) or m.intendedMag > convert_s16(m.faceAngle - 0x4000))

    -- Straining
    if not strainingBlacklist[m.action] and m.pos.y > m.floorHeight then
        if m.input & INPUT_NONZERO_ANALOG ~= 0 then
            e.intendedDYaw = m.intendedYaw - m.faceAngle.y
            e.intendedMag = m.intendedMag / 32;
            e.sidewaysSpeed = e.intendedMag * sins(e.intendedDYaw) * m.forwardVel*0.2
        end
        m.vel.x = m.vel.x + e.sidewaysSpeed * sins(m.faceAngle.y + 0x4000);
        m.vel.z = m.vel.z + e.sidewaysSpeed * coss(m.faceAngle.y + 0x4000);
    end

    --local rotSpeed = math.min(0x20*m.forwardVel, 0x300)
    --m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, rotSpeed, rotSpeed)
    --djui_chat_message_create(tostring(e.prevForwardVel))

    -- Peaking Velocity
    if m.forwardVel > 70 then
        m.forwardVel = clamp_soft(m.forwardVel, -70, 70, 0.5)
    end
    -- Terminal Velocity
    m.forwardVel = clamp(m.forwardVel, -120, 120)
end


local function on_character_select_load()
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_MARIO_UPDATE, squishy_update)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_SET_MARIO_ACTION, squishy_before_action)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_PHYS_STEP, squishy_before_phys_step)
end
hook_event(HOOK_ON_MODS_LOADED, on_character_select_load)