
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

local ACT_SQUISHY_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_BUTT_OR_STOMACH_SLIDE)
local ACT_SQUISHY_GROUND_POUND = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
local ACT_SQUISHY_GROUND_POUND_LAND = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
local ACT_SQUISHY_GROUND_POUND_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING)
local ACT_SQUISHY_FORWARD_ROLLOUT = allocate_mario_action(ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)

--- @param m MarioState
local function act_squishy_slide(m)
    if not m then return 0 end
    local e = gSquishyStates[m.playerIndex]
    if m.actionTimer < 2 then
        e.slideVel = m.forwardVel
    end
    e.slideVel = math.min(e.slideVel + get_mario_floor_steepness(m)*8, 130) - 0.25*(e.slideVel >= 0 and 1 or -1)
    m.slideVelX = sins(m.faceAngle.y)*e.slideVel
    m.slideVelZ = coss(m.faceAngle.y)*e.slideVel
    if m.waterLevel ~= nil and m.pos.y <= m.waterLevel + 30 then
        m.vel.y = 50
    end
    common_slide_action_with_jump(m, ACT_SLIDE_KICK_SLIDE_STOP, ACT_SQUISHY_FORWARD_ROLLOUT, ACT_FORWARD_ROLLOUT, MARIO_ANIM_SLIDE_KICK)
    local rotSpeed = 0x80
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, rotSpeed, rotSpeed)
    if m.input & INPUT_A_PRESSED ~= 0 then
        set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 0)
    end
    m.actionTimer = m.actionTimer + 1
end

local function act_squishy_forward_rollout(m)
    if not m then return 0 end
    if (m.actionState == 0) then
        m.vel.y = 30.0;
        m.actionState = 1;
    end

    play_mario_sound(m, SOUND_ACTION_TERRAIN_JUMP, 0);

    update_air_without_turn(m);

    local switch = common_air_action_step(m, ACT_FREEFALL_LAND_STOP, CHAR_ANIM_FORWARD_SPINNING, AIR_STEP_NONE)
    if switch == AIR_STEP_NONE then
        if (m.actionState == 1) then
            if (set_character_animation(m, CHAR_ANIM_FORWARD_SPINNING) == 4) then
                play_sound(SOUND_ACTION_SPIN, m.marioObj.header.gfx.cameraToObject);
            end
        else
            set_character_animation(m, CHAR_ANIM_GENERAL_FALL);
        end
    elseif switch == AIR_STEP_LANDED then
        set_mario_action(m, ACT_FREEFALL_LAND_STOP, 0);
        play_mario_landing_sound(m, SOUND_ACTION_TERRAIN_LANDING);
    elseif switch == AIR_STEP_HIT_LAVA_WALL then
        lava_boost_on_wall(m);
    end

    if (m.actionState == 1 and is_anim_past_end(m) ~= 0) then
        m.actionState = 2;
    end
    return 0;
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

    if (m.input & INPUT_A_PRESSED) ~= 0 and m.pos.y - m.floorHeight > 100 then
        m.vel.y = 5
        m.forwardVel = -20
        --m.faceAngle.y = m.intendedYaw
        e.poundMaxVel = 0
        return set_mario_action(m, ACT_BACKWARD_ROLLOUT, 0)
    end

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
    elseif (stepResult == AIR_STEP_HIT_WALL) then
        mario_bonk_reflection(m, 0)
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
        set_mario_action(m, ACT_JUMP_KICK, 0)
    end
    if m.input & INPUT_Z_PRESSED ~= 0 then
        set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60)
    end
end

hook_mario_action(ACT_SQUISHY_SLIDE, { every_frame = act_squishy_slide}, INT_ATTACK_SLIDE)
hook_mario_action(ACT_SQUISHY_GROUND_POUND, { every_frame = act_squishy_ground_pound, gravity = act_squishy_ground_pound_gravity}, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_GROUND_POUND_JUMP, { every_frame = act_squishy_ground_pound_jump})
hook_mario_action(ACT_SQUISHY_GROUND_POUND_LAND, act_squishy_ground_pound_land, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_FORWARD_ROLLOUT, { every_frame = act_squishy_forward_rollout}, INT_TRIP)

local function squishy_update(m)
    local e = gSquishyStates[m.playerIndex]
    if (m.action == ACT_PUNCHING or m.action == ACT_MOVE_PUNCHING) and m.actionArg == 9 then
        m.forwardVel = 70
        e.forwardVelStore = 70
        set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end

    if m.controller.buttonPressed & L_TRIG ~= 0 then
        spawn_non_sync_object(id_bhvSquishyNail, E_MODEL_SQUISHY_NAIL, m.pos.x, m.pos.y, m.pos.z,
            function(obj)
                --obj.oPlayerIndex = m.playerIndex
                obj.oVelY = 10 + m.vel.y
                obj.oFaceAngleYaw = m.faceAngle.y
                obj.oForwardVel = 100
            end)
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
        m.vel.y = 50
        return ACT_SQUISHY_GROUND_POUND
    end
    --[[
    if nextAct == ACT_DIVE then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0)
    end
    if nextAct == ACT_AIR_HIT_WALL then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_WALL_SLIDE, 0, m.forwardVel + math.max(m.vel.y*0.7, 0))
    end
    if nextAct == ACT_WALL_KICK_AIR then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_WALL_KICK_AIR, 0)
    end
    ]]
    if nextAct == ACT_BUTT_SLIDE then
        return ACT_SQUISHY_SLIDE
    end
    if nextAct == ACT_SLIDE_KICK then
        m.forwardVel = m.forwardVel + 10
        return ACT_SQUISHY_SLIDE
    end
    if nextAct == ACT_FORWARD_ROLLOUT then
        return ACT_SQUISHY_FORWARD_ROLLOUT
    end

    if nextAct ~= m.action then
        e.gfx.x = 0
        e.gfx.y = 0
        e.gfx.z = 0

        m.actionTimer = 0
    end
end

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