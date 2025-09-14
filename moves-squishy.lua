gSquishyStates = {}
local function reset_squishy_states()
    for i = 0, MAX_PLAYERS - 1 do
        gSquishyStates[i] = {
            poundMaxVel = 0,
            gfx = {x = 0, y = 0, z = 0},
        }
    end
end
reset_squishy_states()

-------------------------
-- Recreated Functions --
-------------------------

local function update_squishy_sliding(m, stopSpeed)
    if (not m) then return end
    local lossFactor;
    local accel;
    local oldSpeed;
    local newSpeed;

    local stopped = false;

    local intendedDYaw = m.intendedYaw - m.slideYaw;
    local forward = coss(intendedDYaw);
    local sideward = sins(intendedDYaw);

    if (forward < 0.0 and m.forwardVel >= 0.0) then
        forward = forward * (0.5 + 0.5 * m.forwardVel / 100.0);
    end

    if mario_get_floor_class(m) == SURFACE_CLASS_VERY_SLIPPERY then
        accel = 10.0;
        lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.98;
    else

        accel = 8.0;
        lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.97;
    end


    oldSpeed = math.sqrt(m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ);

    local oldVelX = m.slideVelX
    m.slideVelX = m.slideVelX + m.slideVelZ * (m.intendedMag / 32.0) * sideward * 0.05;
    m.slideVelZ = m.slideVelZ - oldVelX * (m.intendedMag / 32.0) * sideward * 0.05;

    newSpeed = math.sqrt(m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ);

    if (oldSpeed > 0.0 and newSpeed > 0.0) then
        m.slideVelX = m.slideVelX * oldSpeed / newSpeed;
        m.slideVelZ = m.slideVelZ * oldSpeed / newSpeed;
    end

    update_sliding_angle(m, accel, lossFactor);

    if (m.playerIndex == 0 and mario_floor_is_slope(m) == 0 and m.forwardVel * m.forwardVel < stopSpeed * stopSpeed) then
        mario_set_forward_vel(m, 0.0);
        return 1;
    end

    return 0;
end


-------------
-- Actions --
-------------

local ACT_SQUISHY_GROUND_POUND = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ATTACKING)
local ACT_SQUISHY_GROUND_POUND_LAND = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_STATIONARY | ACT_FLAG_ATTACKING)
local ACT_SQUISHY_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_ATTACKING)
local ACT_SQUISHY_SLIDE_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ATTACKING)

local poundVel = 4
---@param m MarioState
local function act_squishy_ground_pound(m)
    if not m then return 0 end
    local e = gSquishyStates[m.playerIndex]

    if m.actionTimer < 2 then
        m.vel.y = poundVel*(m.actionArg == 0 and 10 or 15)
    end

    if m.forwardVel < 0 and m.actionArg == 0 then
        m.actionArg = 1
    end

    e.poundMaxVel = clamp(math.max(e.poundMaxVel, math.abs(m.vel.y)*0.8, m.forwardVel), 0, 60)

    m.vel.y = m.vel.y - poundVel
    e.gfx.y = e.gfx.y + m.vel.y*100

    play_sound_if_no_flag(m, SOUND_ACTION_THROW, MARIO_ACTION_SOUND_PLAYED);

    set_character_animation(m, CHAR_ANIM_GROUND_POUND);

    if (m.input & INPUT_B_PRESSED) ~= 0 then
        m.vel.y = 5
        mario_set_forward_vel(m, math.max(30, m.forwardVel))
        m.faceAngle.y = m.intendedYaw
        e.poundMaxVel = 0
        return set_mario_action(m, ACT_SQUISHY_SLIDE_AIR, 0)
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
    end

    m.actionTimer = m.actionTimer + 1
    return 0;
end

---@param m MarioState
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
            return set_mario_action(m, ACT_DOUBLE_JUMP, 0)
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
        return set_mario_action(m, ACT_SQUISHY_SLIDE_AIR, 0)
    end

    landing_step(m, CHAR_ANIM_START_CROUCHING, ACT_CROUCHING);
    m.actionTimer = m.actionTimer + 1
    return 0

end

---@param m MarioState
local function act_squishy_slide(m)
    if not m then return 0 end
    local e = gSquishyStates[m.playerIndex]
    
    if m.actionTimer == 0 then -- Transistion into slide
        m.forwardVel = m.forwardVel + 10
        m.slideYaw = m.faceAngle.y
        m.slideVelX = m.forwardVel*sins(m.faceAngle.y)
        m.slideVelZ = m.forwardVel*coss(m.faceAngle.y)
        m.vel.x = m.slideVelX
        m.vel.z = m.slideVelZ
    elseif (m.input & (INPUT_A_PRESSED | INPUT_B_PRESSED) ~= 0) then -- Check for Rollout
        queue_rumble_data_mario(m, 5, 80);
        return set_mario_action(m, (m.forwardVel > 0 and ACT_FORWARD_ROLLOUT or ACT_BACKWARD_ROLLOUT), 0)
    end

    m.forwardVel = clamp(m.forwardVel, 30, 130)
    m.slideVelX = sins(m.slideYaw)*m.forwardVel
    m.slideVelZ = coss(m.slideYaw)*m.forwardVel

    play_mario_landing_sound_once(m, SOUND_ACTION_TERRAIN_BODY_HIT_GROUND);

    update_squishy_sliding(m, 0)
    common_slide_action(m, ACT_SLIDE_KICK_SLIDE_STOP, ACT_SQUISHY_SLIDE_AIR, CHAR_ANIM_SLIDE_KICK);

    m.actionTimer = m.actionTimer + 1
end

---@param m MarioState
local function act_squishy_slide_air(m)
    if not m then return 0 end
    local e = gSquishyStates[m.playerIndex]

    if m.actionTimer == 0 then -- Transistion into slide
        m.slideYaw = m.faceAngle.y
        m.slideVelX = m.forwardVel*sins(m.faceAngle.y)
        m.slideVelZ = m.forwardVel*coss(m.faceAngle.y)
        m.vel.x = m.slideVelX
        m.vel.z = m.slideVelZ
    elseif (m.input & (INPUT_A_PRESSED | INPUT_B_PRESSED) ~= 0) then -- Check for Rollout
        set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE, 0);
        return set_mario_action(m, (m.forwardVel > 0 and ACT_FORWARD_ROLLOUT or ACT_BACKWARD_ROLLOUT), 0)
    end

    common_air_action_step(m, ACT_SQUISHY_SLIDE, CHAR_ANIM_SLIDE_KICK, AIR_STEP_NONE)

    m.actionTimer = m.actionTimer + 1
end

hook_mario_action(ACT_SQUISHY_GROUND_POUND, act_squishy_ground_pound, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_GROUND_POUND_LAND, act_squishy_ground_pound_land, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_SLIDE, act_squishy_slide, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_SLIDE_AIR, act_squishy_slide_air, INT_FAST_ATTACK_OR_SHELL)

---@param m MarioState
local function squishy_update(m)
    local e = gSquishyStates[m.playerIndex]
    
    -- GFX Update
    if e.gfx.x ~= 0 then m.marioObj.header.gfx.angle.x = m.faceAngle.x + e.gfx.x end
    if e.gfx.y ~= 0 then m.marioObj.header.gfx.angle.y = m.faceAngle.y + e.gfx.y end
    if e.gfx.z ~= 0 then m.marioObj.header.gfx.angle.z = m.faceAngle.z + e.gfx.z end
end

---@param m MarioState
local function before_set_action(m, nextAct)
    local e = gSquishyStates[m.playerIndex]

    -- Override Base Game Actions
    if nextAct == ACT_GROUND_POUND then
        return set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 0)
    end

    if nextAct == ACT_SLIDE_KICK then
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end

    -- State Reset
    if nextAct ~= m.action then
        e.gfx.x = 0
        e.gfx.y = 0
        e.gfx.z = 0

        m.actionTimer = 0
    end
end

_G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_MARIO_UPDATE, squishy_update)
_G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_SET_MARIO_ACTION, before_set_action)
_G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ON_LEVEL_INIT, reset_squishy_states)