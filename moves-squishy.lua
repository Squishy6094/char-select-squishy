
gSquishyStates = {}
for i = 0, MAX_PLAYERS - 1 do
    gSquishyStates[i] = {
        forwardVelStore = 0,
        poundMaxVel = 0,
        slideVel = 0,
        prevWallAngle = 0,
        groundpoundCancels = 0,
        gfx = {x = 0, y = 0, z = 0},
    }
end

local ACT_SQUISHY_DIVE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
local ACT_SQUISHY_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_BUTT_OR_STOMACH_SLIDE)
local ACT_SQUISHY_GROUND_POUND = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
local ACT_SQUISHY_GROUND_POUND_LAND = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
local ACT_SQUISHY_GROUND_POUND_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)
local ACT_SQUISHY_WALL_SLIDE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)
local ACT_SQUISHY_WALL_KICK_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION )


--- @param m MarioState
local function act_squishy_dive(m)
    local e = gSquishyStates[m.playerIndex]
    common_air_action_step(m, ACT_DIVE_SLIDE, CHAR_ANIM_DIVE, AIR_STEP_NONE)
    if m.actionTimer == 1 then
        mario_set_forward_vel(m, m.forwardVel + 15)
        --m.vel.y = 20
    end
    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_slide(m)
    local e = gSquishyStates[m.playerIndex]
    if m.actionTimer < 2 then
        e.slideVel = m.forwardVel
    end
    e.slideVel = math.min(e.slideVel + get_mario_floor_steepness(m)*8, 130) - 0.25
    m.slideVelX = sins(m.faceAngle.y)*e.slideVel
    m.slideVelZ = coss(m.faceAngle.y)*e.slideVel
    if m.waterLevel ~= nil and m.pos.y <= m.waterLevel + 30 then
        m.vel.y = 50
    end
    common_slide_action_with_jump(m, ACT_SLIDE_KICK_SLIDE_STOP, ACT_DOUBLE_JUMP, ACT_FORWARD_ROLLOUT, MARIO_ANIM_SLIDE_KICK)
    local rotSpeed = 0x80
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, rotSpeed, rotSpeed)
    if m.input & INPUT_A_PRESSED ~= 0 then
        set_mario_action_and_y_vel(m, ACT_FORWARD_ROLLOUT, 0, 30)
    end
    m.actionTimer = m.actionTimer + 1
end

local function act_squishy_ground_pound(m)
    if not m then return 0 end
    local e = gSquishyStates[m.playerIndex]

    if m.actionTimer < 2 then
        m.vel.y = math.max(m.vel.y, 50)
    end

    if m.forwardVel < 0 and m.actionArg == 0 then
        m.actionArg = 1
    end

    e.poundMaxVel = clamp(math.max(e.poundMaxVel, math.abs(m.vel.y)*0.8, m.forwardVel), 0, 60)

    e.gfx.y = e.gfx.y + m.vel.y*100

    play_sound_if_no_flag(m, SOUND_ACTION_THROW, MARIO_ACTION_SOUND_PLAYED);

    set_character_animation(m, CHAR_ANIM_GROUND_POUND);


    --[[
    if (m.input & INPUT_B_PRESSED) ~= 0 then
        m.vel.y = 5
        mario_set_forward_vel(m, math.max(30, m.forwardVel))
        m.faceAngle.y = m.intendedYaw
        e.poundMaxVel = 0
        return set_mario_action(m, ACT_SQUISHY_SLIDE_AIR, 0)
    end]]

    local stepResult = perform_air_step(m, 0);
    if (stepResult == AIR_STEP_LANDED) then
        if (m.playerIndex == 0) then set_camera_shake_from_hit(SHAKE_GROUND_POUND); end
        if (should_get_stuck_in_ground(m) ~= 0) then
            queue_rumble_data_mario(m, 5, 80);
            play_character_sound(m, CHAR_SOUND_OOOF2);
            set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE, 0);
            return set_mario_action(m, ACT_FEET_STUCK_IN_GROUND, 0);
        else
            play_mario_heavy_landing_sound(m, SOUND_ACTION_TERRAIN_HEAVY_LANDING);
            set_mario_particle_flags(m, (PARTICLE_MIST_CIRCLE | PARTICLE_HORIZONTAL_STAR), 0);
            return set_mario_action(m, ACT_SQUISHY_GROUND_POUND_LAND, m.actionArg);
        end
    end

    m.actionTimer = m.actionTimer + 1
    return 0;
end


--- @param m MarioState
local function act_squishy_ground_pound_gravity(m)
    m.vel.y = math.max(m.vel.y - 7, -200)
end

local function act_squishy_ground_pound_land(m)
    if not m then return 0 end
    local e = gSquishyStates[m.playerIndex]

    if m.actionTimer == 0 then
        m.vel.x = 0
        m.vel.z = 0
        m.slideVelX = 0
        m.slideVelZ = 0
        set_mario_animation(m, CHAR_ANIM_CROUCHING)
    end

    m.actionState = 1;
    if (m.input & INPUT_UNKNOWN_10 ~= 0) then
        return drop_and_set_mario_action(m, ACT_SHOCKWAVE_BOUNCE, 0);
    end

    if (m.input & INPUT_OFF_FLOOR ~= 0) then
        return set_mario_action(m, ACT_FREEFALL, 0);
    end

    if (m.input & INPUT_ABOVE_SLIDE ~= 0) then
        m.faceAngle.y = m.floorAngle
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 0);
    end

    if (m.input & INPUT_A_PRESSED) ~= 0 then
        if m.actionArg == 0 then
            m.vel.y = 70
            return set_mario_action(m, ACT_SQUISHY_GROUND_POUND_JUMP, 0)
        elseif m.actionArg == 1 then
            mario_set_forward_vel(m, -30)
            return set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 2)
        else
            m.vel.y = 200
            mario_set_forward_vel(m, -50)
            return set_mario_action(m, ACT_BACKFLIP, 1)
        end
    end

    if (m.input & INPUT_B_PRESSED) ~= 0 then
        mario_set_forward_vel(m, e.poundMaxVel)
        m.faceAngle.y = m.intendedYaw
        e.poundMaxVel = 0
        set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE, 0);
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end

    landing_step(m, CHAR_ANIM_START_CROUCHING, ACT_CROUCHING);
    m.actionTimer = m.actionTimer + 1
    return 0

end

--- @param m MarioState
local function act_squishy_ground_pound_jump(m)
    local e = gSquishyStates[m.playerIndex]
    common_air_action_step(m, ACT_JUMP_LAND, CHAR_ANIM_SINGLE_JUMP, AIR_STEP_NONE)
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_YAHOO_WAHA_YIPPEE)
        e.gfx.y = 0x20000
    end
    e.gfx.y = e.gfx.y*0.8
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
    local e = gSquishyStates[m.playerIndex]
    local airStep = m.vel.y < 30 and AIR_STEP_CHECK_LEDGE_GRAB or AIR_STEP_NONE
    perform_air_step(m, airStep)
    set_mario_animation(m, MARIO_ANIM_START_WALLKICK)
    
    if e.groundpoundCancels >= 3 then
        return set_mario_action(m, ACT_HARD_BACKWARD_AIR_KB, 0)
    end

    if m.actionTimer < 2 then
        e.forwardVelStore = math.sqrt(m.vel.z^2 + m.vel.x^2) + math.min(m.vel.y, 0)
        m.vel.y = e.forwardVelStore
        if m.wall ~= nil then
            e.prevWallAngle = atan2s(m.wall.normal.z, m.wall.normal.x)
        end
    end

    m.vel.y = m.vel.y + 0.3
    set_mario_particle_flag(m, PARTICLE_DUST)
    if m.wall == nil then
        m.faceAngle.y = e.prevWallAngle
        if m.pos.y == m.floorHeight and e.prevFloorDist < 100 then
            set_mario_action(m, ACT_FREEFALL_LAND, 0)
        else
            m.faceAngle.y = convert_s16(m.faceAngle.y + 0x8000)
            set_mario_action_and_y_vel(m, ACT_FORWARD_ROLLOUT, 0, m.vel.y)
            m.pos.y = m.pos.y + 10
            m.forwardVel = m.forwardVel * 0.4
        end
    else
        local wallAngle = atan2s(m.wall.normal.z, m.wall.normal.x)
        local wallAngleDiff = (wallAngle - e.prevWallAngle)
        if wallAngleDiff ~= 0 and (wallAngleDiff < 0x3F00 and wallAngleDiff > -0x3F00) then
            local velAngle = atan2s(m.vel.z, m.vel.x) + wallAngleDiff
            m.vel.x = e.forwardVelStore * sins(velAngle)
            m.vel.z = e.forwardVelStore * coss(velAngle)
        end
        e.prevWallAngle = wallAngle
        m.marioObj.header.gfx.angle.y = wallAngle
        e.prevFloorDist = m.pos.y - m.floorHeight
        play_sound(SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, m.marioObj.header.gfx.cameraToObject);
    end
    
    if m.input & INPUT_A_PRESSED ~= 0 then
        m.faceAngle.y = e.prevWallAngle

        play_sound((m.flags & MARIO_METAL_CAP ~= 0) and SOUND_ACTION_METAL_BONK or SOUND_ACTION_BONK,
                m.marioObj.header.gfx.cameraToObject);

        set_mario_action(m, ACT_SQUISHY_WALL_KICK_AIR, 0)
    end

    if m.input & INPUT_Z_PRESSED ~= 0 then
        m.faceAngle.y = e.prevWallAngle

        play_sound((m.flags & MARIO_METAL_CAP ~= 0) and SOUND_ACTION_METAL_BONK or SOUND_ACTION_BONK,
                m.marioObj.header.gfx.cameraToObject);

        m.forwardVel = 20
        set_mario_action(m, ACT_FREEFALL, 0)
    end

    m.actionTimer = m.actionTimer + 1
end

local function act_squishy_wall_kick_air(m)
    local e = gSquishyStates[m.playerIndex]
    if m.actionTimer == 1 then
        m.vel.y = math.max(m.vel.y, 30)
        m.forwardVel = math.max(35, math.abs(m.vel.y*0.7)) --math.abs(e.forwardVelStore*0.8)
    end

    if (m.input & INPUT_B_PRESSED ~= 0) then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0);
    end

    if (m.input & INPUT_Z_PRESSED ~= 0) then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60);
    end

    play_mario_jump_sound(m);
    common_air_action_step(m, ACT_JUMP_LAND, MARIO_ANIM_SLIDEJUMP, AIR_STEP_CHECK_LEDGE_GRAB | AIR_STEP_CHECK_HANG);
    m.actionTimer = m.actionTimer + 1
end

hook_mario_action(ACT_SQUISHY_DIVE, { every_frame = act_squishy_dive}, INT_ANY_ATTACK)
hook_mario_action(ACT_SQUISHY_SLIDE, { every_frame = act_squishy_slide}, INT_ATTACK_SLIDE)
hook_mario_action(ACT_SQUISHY_GROUND_POUND, { every_frame = act_squishy_ground_pound, gravity = act_squishy_ground_pound_gravity}, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_GROUND_POUND_JUMP, { every_frame = act_squishy_ground_pound_jump})
hook_mario_action(ACT_SQUISHY_GROUND_POUND_LAND, act_squishy_ground_pound_land, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_WALL_SLIDE, {every_frame = act_squishy_wall_slide}, 0)
hook_mario_action(ACT_SQUISHY_WALL_KICK_AIR, {every_frame = act_squishy_wall_kick_air})

local function squishy_update(m)
    local e = gSquishyStates[m.playerIndex]
    if (m.action == ACT_PUNCHING or m.action == ACT_MOVE_PUNCHING) and m.actionArg == 9 then
        m.forwardVel = 70
        e.forwardVelStore = 70
        set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end
    
    if e.gfx.x ~= 0 then m.marioObj.header.gfx.angle.x = m.faceAngle.x + e.gfx.x end
    if e.gfx.y ~= 0 then m.marioObj.header.gfx.angle.y = m.faceAngle.y + e.gfx.y end
    if e.gfx.z ~= 0 then m.marioObj.header.gfx.angle.z = m.faceAngle.z + e.gfx.z end

end

---@param m MarioState
local function squishy_before_action(m, nextAct)
    local e = gSquishyStates[m.playerIndex]
    if m.playerIndex == 0 then
        --djui_chat_message_create(tostring(gSquishyStates[0].forwardVelStore))
    end
    if nextAct == ACT_GROUND_POUND then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60)
    end
    if nextAct == ACT_DIVE then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0)
    end
    if nextAct == ACT_AIR_HIT_WALL then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_WALL_SLIDE, 0, m.forwardVel + math.max(m.vel.y*0.7, 0))
    end
    if nextAct == ACT_WALL_KICK_AIR then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_WALL_KICK_AIR, 0)
    end
    if nextAct == ACT_BUTT_SLIDE then
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 1)
    end
    if nextAct == ACT_SLIDE_KICK then
        m.forwardVel = m.forwardVel + 10
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end

    if nextAct ~= m.action then
        e.gfx.x = 0
        e.gfx.y = 0
        e.gfx.z = 0

        m.actionTimer = 0
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
    local e = gSquishyStates[m.playerIndex]
    -- Peaking Velocity
    if m.forwardVel > 70 then
        m.forwardVel = clamp_soft(m.forwardVel, -70, 70, 0.5)
    end
    -- Terminal Velocity
    m.forwardVel = clamp(m.forwardVel, -130, 130)
end


local function on_character_select_load()
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_MARIO_UPDATE, squishy_update)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_SET_MARIO_ACTION, squishy_before_action)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_PHYS_STEP, squishy_before_phys_step)
end
hook_event(HOOK_ON_MODS_LOADED, on_character_select_load)