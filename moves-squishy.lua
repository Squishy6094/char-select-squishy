
-------------
-- Moveset --
-------------

gGlobalSyncTable.squishySpeedMult = 1

gSquishyExtraStates = {}
for i = 0, MAX_PLAYERS - 1 do
    gSquishyExtraStates[i] = {
        forwardVelStore = 0,
        yVelStore = 0,
        groundPoundJump = true,
        groundPoundFromRollout = true,
        prevForwardVel = 0,
        intendedDYaw = 0,
        intendedMag = 0,
        sidewaysSpeed = 0,
        prevFloorDist = 0,
        spamBurnout = 0,
        forceDefaultWalk = false,
        prevWallAngle = 0,
        groundpoundCancels = 0,
        panicking = false,
        
        gfxAnimX = 0,
        gfxAnimY = 0,
        gfxAnimZ = 0,
    }
end

gPlayerSyncTable[0].squishyHasShell = false
gPlayerSyncTable[0].spamBurnout = 0

local spamBurnoutMax = 100

local function clamp(num, min, max)
    return math.min(math.max(num, min), max)
end

local function clamp_soft(num, min, max, rate)
    if num < min then
        num = num + rate
        num = math.min(num, max)
    elseif num > max then
        num = num - rate
        num = math.max(num, min)
    end
    return num
end

local function lerp(a, b, t)
    return a * (1 - t) + b * t
end

local function invlerp(x, a, b)
    return clamp((x - a) / (b - a), 0.0, 1.0)
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

local function vec3f_angle_between(a, b)
    return math.acos(vec3f_dot(a, b) / (vec3f_length(a) * vec3f_length(b)))
end

local function vec3f_non_nan(v)
    if v.x ~= v.x then v.x = 0 end
    if v.y ~= v.y then v.y = 0 end
    if v.z ~= v.z then v.z = 0 end
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
        local yVel = math.sqrt(m.vel.x^2 + m.vel.y^2)*get_mario_floor_steepness(m)
        local velAngle = (math.sqrt(m.vel.z^2 + m.vel.x^2) > 0 and atan2s(m.vel.z, m.vel.x) or m.faceAngle.y)
        local angleDif = convert_s16(velAngle - m.faceAngle.y)
        return yVel * ((angleDif > 0x4000 or angleDif < -0x4000) and 1 or -1)
    else
        return m.vel.y
    end
end

local function squishy_has_koopa_shell(m, setShellState)
    if setShellState == nil then
        return gPlayerSyncTable[m.playerIndex].squishyHasShell
    else
        gPlayerSyncTable[m.playerIndex].squishyHasShell = setShellState
    end
end

local function update_spam_burnout(m, burnTimer)
    local e = gSquishyExtraStates[m.playerIndex]
    if m.playerIndex == 0 then
        if burnTimer == nil then
            return e.spamBurnout
        else
            e.spamBurnout = burnTimer
            gPlayerSyncTable[0].spamBurnout = burnTimer
        end
    else
        local netSpam = gPlayerSyncTable[m.playerIndex].spamBurnout
        return (netSpam and netSpam or 0)
    end
end

----------------------------------------
-- Ported n' Modified Mario Functions --
----------------------------------------

local function update_speed_cap(m, peakVel, force)
    local e = gSquishyExtraStates[m.playerIndex]
    if force == nil then force = false end
    if not force then
        if currRomhack == ROMHACK_SOMARI then return end
    end
    if peakVel == nil then peakVel = 30 end
    peakVel = peakVel * gGlobalSyncTable.squishySpeedMult
    if e.panicking then
        peakVel = peakVel * 1.5
    end
    m.forwardVel = clamp_soft(m.forwardVel, -peakVel, peakVel, 0.1*math.floor(math.abs(m.forwardVel)/peakVel))
    m.slideVelX = clamp_soft(m.slideVelX, -peakVel, peakVel, 0.1*math.floor(math.abs(m.slideVelX)/peakVel))
    m.slideVelZ = clamp_soft(m.slideVelZ, -peakVel, peakVel, 0.1*math.floor(math.abs(m.slideVelZ)/peakVel))
    if m.vel.y > 0 then
        m.vel.y = clamp_soft(m.vel.y, -peakVel, peakVel, 0.1*math.floor(math.abs(m.vel.y)/peakVel))
    end
end

local function update_squishy_sliding_angle(m, accel, lossFactor)
    local newFacingDYaw;
    local facingDYaw;

    local floor = m.floor;
    local slopeAngle = atan2s(floor.normal.z, floor.normal.x);
    local steepness = math.sqrt(floor.normal.x * floor.normal.x + floor.normal.z * floor.normal.z);

    m.slideVelX = m.slideVelX + accel * steepness * sins(slopeAngle);
    m.slideVelZ = m.slideVelZ + accel * steepness * coss(slopeAngle);

    m.slideVelX = m.slideVelX * lossFactor;
    m.slideVelZ = m.slideVelZ * lossFactor;

    m.slideYaw = atan2s(m.slideVelZ, m.slideVelX);

    facingDYaw = m.faceAngle.y - m.slideYaw;
    newFacingDYaw = facingDYaw;

    --! -0x4000 not handled - can slide down a slope while facing perpendicular to it
    -- Fixed
    if (newFacingDYaw > 0 and newFacingDYaw <= 0x4000) then
        newFacingDYaw = (newFacingDYaw - 0x200)
        if (newFacingDYaw < 0) then
            newFacingDYaw = 0;
        end
    elseif (newFacingDYaw >= -0x4000 and newFacingDYaw < 0) then
        newFacingDYaw = (newFacingDYaw + 0x200)
        if (newFacingDYaw > 0) then
            newFacingDYaw = 0;
        end
    elseif (newFacingDYaw > 0x4000 and newFacingDYaw < 0x8000) then
        newFacingDYaw = (newFacingDYaw + 0x200)
        if (newFacingDYaw > 0x8000) then
            newFacingDYaw = 0x8000;
        end
    elseif (newFacingDYaw > -0x8000 and newFacingDYaw < -0x4000) then
        newFacingDYaw = (newFacingDYaw - 0x200)
        if (newFacingDYaw < -0x8000) then
            newFacingDYaw = -0x8000;
        end
    end

    m.faceAngle.y = m.slideYaw + newFacingDYaw;

    m.vel.x = m.slideVelX;
    m.vel.y = 0.0;
    m.vel.z = m.slideVelZ;

    mario_update_moving_sand(m);
    mario_update_windy_ground(m);

    m.forwardVel = math.sqrt(m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ);

    if (newFacingDYaw < -0x4000 or newFacingDYaw > 0x4000) then
        m.forwardVel = m.forwardVel * -1.0;
    end
end

local function update_squishy_sliding(m, stopSpeed)
    local lossFactor;
    local accel;
    local oldSpeed;
    local newSpeed;

    local stopped = false;

    local intendedDYaw = m.intendedYaw - m.slideYaw;
    local forward = coss(intendedDYaw);
    local sideward = sins(intendedDYaw);

    --! 10k glitch
    if (forward < 0.0 and m.forwardVel >= 0.0) then
        forward = forward * (0.5 + 0.5 * m.forwardVel / 100.0);
    end

    accel = 10.0;
    lossFactor = 1--m.intendedMag / 32.0 * forward * 0.02 + 0.98;

    oldSpeed = math.sqrt(m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ);

    --! This is attempting to use trig derivatives to rotate Mario's speed.
    -- It is slightly off/asymmetric since it uses the new X speed, but the old
    -- Z speed.
    m.slideVelX = m.slideVelX + m.slideVelZ * (m.intendedMag / 32.0) * sideward * 0.05;
    m.slideVelZ = m.slideVelZ - m.slideVelX * (m.intendedMag / 32.0) * sideward * 0.05;

    newSpeed = math.sqrt(m.slideVelX * m.slideVelX + m.slideVelZ * m.slideVelZ);

    if (oldSpeed > 0.0 and newSpeed > 0.0) then
        m.slideVelX = m.slideVelX * oldSpeed / newSpeed;
        m.slideVelZ = m.slideVelZ * oldSpeed / newSpeed;
    end

    update_squishy_sliding_angle(m, accel, lossFactor);

    if (mario_floor_is_slope(m) == 0 and m.forwardVel * m.forwardVel < stopSpeed * stopSpeed) then
        mario_set_forward_vel(m, 0.0);
        stopped = true;
    end

    return stopped;
end

local function update_squishy_walking_speed(m)
    local maxTargetSpeed;
    local targetSpeed;

    if (m.floor ~= nil and m.floor.type == SURFACE_SLOW) then
        maxTargetSpeed = 23
    else
        maxTargetSpeed = 31
    end

    targetSpeed = m.intendedMag < maxTargetSpeed and m.intendedMag or maxTargetSpeed;

    --[[
    if (m.quicksandDepth > 10) then
        targetSpeed = targetSpeed * (6.25 / m.quicksandDepth)
    end
    ]]

    if (m.forwardVel <= 0.0) then
        m.forwardVel = m.forwardVel + 1.1;
    elseif (m.forwardVel <= targetSpeed) then
        m.forwardVel = m.forwardVel + 1.1 - m.forwardVel / 43.0;
    elseif (m.floor.normal.y >= 0.95) then
        m.forwardVel = m.forwardVel - 1.0;
    end

    --[[
    if (m.forwardVel > 48.0) then
        m.forwardVel = 48.0;
    end
    ]]

    m.faceAngle.x = 0

    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x800 - m.forwardVel*2, 0x800 - m.forwardVel*2);
    apply_slope_accel(m);
end

local function squishy_allow_midair_spin(m, allow)
    if omm_moveset_enabled(m) and m.input & INPUT_A_PRESSED ~= 0 and allow ~= false then
        set_mario_action(m, ACT_OMM_MIDAIR_SPIN, 0)
    end
end

local function squishy_allow_spin_jump(m, allow)
    if omm_moveset_enabled(m) and m.controller.buttonDown & Y_BUTTON ~= 0 and allow ~= false then
        if m.action & ACT_FLAG_AIR ~= 0 then
            if m.vel.y <= 10 then
                set_mario_action(m, ACT_OMM_SPIN_JUMP, 0)
            end
        else
            set_mario_action(m, ACT_OMM_SPIN_GROUND, 0)
        end
    end
end

local function update_omm_air_rotation(m)
    if not omm_moveset_enabled(m) then return end
    local vmin = 8
    local vmax = 32
    local hmin = 0x800
    local hmax = 0x4000
    if m.action & ACT_FLAG_AIR ~= 0 then
        vmax = 24
        hmin = 0x200
        hmax = 0x2000
    end
    local vel = math.max(math.abs(m.forwardVel), 1)
    local mag = m.intendedMag / (32)
    local handling = ((hmin + (1.0 - invlerp(vel, vmin, vmax)^2) * (hmax - hmin)) * mag)
    m.faceAngle.y = convert_s16(m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, handling, handling))
    mario_set_forward_vel(m, m.forwardVel)
end

ACT_SQUISHY_WALKING = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_MOVING )
ACT_SQUISHY_CROUCH_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_SHORT_HITBOX )
ACT_SQUISHY_DIVE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_DIVING | ACT_FLAG_AIR)
ACT_SQUISHY_DIVE_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_DIVING | ACT_FLAG_BUTT_OR_STOMACH_SLIDE)
ACT_SQUISHY_LONG_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_BUTT_OR_STOMACH_SLIDE | ACT_FLAG_DIVING | ACT_FLAG_SHORT_HITBOX)
ACT_SQUISHY_SLIDE_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_AIR | ACT_FLAG_DIVING | ACT_FLAG_SHORT_HITBOX)
ACT_SQUISHY_ROLLOUT = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_GROUND_POUND = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_GROUND_POUND_LAND = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
ACT_SQUISHY_GROUND_POUND_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR | ACT_FLAG_CONTROL_JUMP_HEIGHT)
ACT_SQUISHY_WALL_SLIDE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_FIRE_BURN = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_SWIM_IDLE = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING | ACT_FLAG_WATER_OR_TEXT | ACT_FLAG_STATIONARY)
ACT_SQUISHY_SWIM_MOVING = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING | ACT_FLAG_WATER_OR_TEXT | ACT_FLAG_MOVING)
ACT_SQUISHY_SWIM_ATTACK = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING | ACT_FLAG_WATER_OR_TEXT | ACT_FLAG_MOVING | ACT_FLAG_ATTACKING)
ACT_SQUISHY_WALL_KICK_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_SIDE_FLIP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_LEDGE_GRAB = allocate_mario_action(ACT_GROUP_AUTOMATIC | ACT_FLAG_STATIONARY)

local function act_squishy_walking(m)
    local startPos = {x = 0, y = 0, z = 0}
    local startYaw = m.faceAngle.y

    mario_drop_held_object(m)

    --[[
    if (should_begin_sliding(m)) then
        return set_mario_action(m, ACT_BEGIN_SLIDING, 0)
    end
    ]]

    if (m.input & INPUT_FIRST_PERSON ~= 0) then
        return begin_braking_action(m)
    end

    if (m.input & INPUT_A_PRESSED ~= 0) then
        return set_jump_from_landing(m)
    end

    if (check_ground_dive_or_punch(m) ~= 0) then
        if omm_moveset_enabled(m) then
            return set_mario_action_and_y_vel(m, ACT_JUMP_KICK, 0, 30)
        end
        return true
    end

    if (m.input & INPUT_NONZERO_ANALOG == 0) and m.forwardVel < 30 then
        return begin_braking_action(m);
    end

    if (analog_stick_held_back(m) == 1 and m.forwardVel >= 16) then
        set_mario_action(m, ACT_TURNING_AROUND, 0)
    end
    
    if (m.input & INPUT_Z_PRESSED ~= 0) then
        return set_mario_action(m, ACT_CROUCH_SLIDE, 0)
    end

    m.actionState = 0

    vec3f_copy(startPos, m.pos);
    update_squishy_walking_speed(m)
    squishy_allow_spin_jump(m)

    local switch = perform_ground_step(m)
    if switch == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ACT_FREEFALL, 0);
        set_mario_animation(m, MARIO_ANIM_GENERAL_FALL);
        return
    elseif switch == GROUND_STEP_NONE then
        anim_and_audio_for_walk(m)
        if (m.intendedMag - m.forwardVel > 16.0) then
            m.particleFlags = PARTICLE_DUST;
        end
        return
    elseif switch == GROUND_STEP_HIT_WALL then
        push_or_sidle_wall(m, startPos);
        m.actionTimer = 0;
        return
    end

    check_ledge_climb_down(m);
    --tilt_body_walking(m, startYaw);
    return false;
end

--- @param m MarioState
local function act_squishy_crouch_slide(m)
    local e = gSquishyExtraStates[m.playerIndex]

    if m.actionTimer == 0 then
        set_mario_animation(m, MARIO_ANIM_CROUCHING)
    end
    m.forwardVel = m.forwardVel*0.95 + get_mario_floor_steepness(m)*4

    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x200, 0x200)
    m.slideVelX = sins(m.faceAngle.y)*m.forwardVel
    m.slideVelZ = coss(m.faceAngle.y)*m.forwardVel

    if update_squishy_sliding(m, 4) then
        set_mario_action(m, ACT_CROUCHING, 0)
    end
    common_slide_action(m, ACT_CROUCHING, ACT_FREEFALL, MARIO_ANIM_CROUCHING)
    
    if math.abs(m.forwardVel) < 1 then
        set_mario_action(m, ACT_CROUCHING, 0)
        m.forwardVel = 0
    end
    if m.pos.y > m.floorHeight then
        set_mario_action(m, ACT_FREEFALL, 0)
    end
    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_A_PRESSED ~= 0 then
        set_mario_action(m, (m.forwardVel > 0 and ACT_SQUISHY_LONG_JUMP or ACT_LONG_JUMP), 0)
    end
    if m.input & INPUT_B_PRESSED ~= 0 then
        m.forwardVel = m.forwardVel + 20
        set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end
    if m.input & INPUT_Z_DOWN == 0 then
        set_mario_action(m, ACT_SQUISHY_WALKING, 0)
    end
end

--- @param m MarioState
local function act_squishy_dive(m)
    local e = gSquishyExtraStates[m.playerIndex]
    common_air_action_step(m, ACT_SQUISHY_DIVE_SLIDE, CHAR_ANIM_DIVE, AIR_STEP_NONE)
    update_omm_air_rotation(m)
    if m.actionTimer == 0 then
        mario_set_forward_vel(m, m.forwardVel + 12)
    end
    
    if mario_check_object_grab(m) ~= 0 then
        mario_grab_used_object(m)
        if m.interactObj.behavior == get_behavior_from_id(id_bhvBowser) then
            set_mario_action(m, ACT_PICKING_UP_BOWSER, 0)
            m.marioBodyState.grabPos = GRAB_POS_BOWSER
            return true
        elseif m.interactObj.oInteractionSubtype & INT_SUBTYPE_GRABS_MARIO ~= 0 then
            return false
        else
            m.marioBodyState.grabPos = GRAB_POS_LIGHT_OBJ
            return true
        end
    end

    m.actionTimer = m.actionTimer + 1
end

local function act_squishy_dive_slide(m)
        if (m.input & (INPUT_A_PRESSED | INPUT_B_PRESSED) ~= 0) then
            queue_rumble_data(5, 80);
            return set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, 30);
        end

    if (update_squishy_sliding(m, 4.0)) then
        return set_mario_action(m, ACT_STOMACH_SLIDE_STOP, 0)
    end

    common_slide_action(m, ACT_STOMACH_SLIDE_STOP, ACT_SQUISHY_DIVE, MARIO_ANIM_SLIDE_DIVE);
    update_speed_cap(m, 3)
    m.actionTimer = m.actionTimer + 1;
end

--- @param m MarioState
local function act_squishy_long_jump(m)
    local e = gSquishyExtraStates[m.playerIndex]
    if m.actionTimer == 0 then
        m.forwardVel = (m.forwardVel + 20)
        e.gfxAnimX = -0x10000 * math.floor(m.forwardVel/50)
        m.pos.y = m.pos.y + 10
        m.vel.y = 30
    end
    m.vel.y = m.vel.y + 2
    common_air_action_step(m, ACT_SQUISHY_CROUCH_SLIDE, CHAR_ANIM_SLOW_LONGJUMP, AIR_STEP_CHECK_LEDGE_GRAB)
    squishy_allow_midair_spin(m)
    update_omm_air_rotation(m)
    e.gfxAnimX = e.gfxAnimX * 0.8
    m.marioObj.header.gfx.angle.x = e.gfxAnimX
    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_slide(m)
    local e = gSquishyExtraStates[m.playerIndex]
    if m.actionTimer == 0 then
        m.slideVelX = sins(m.faceAngle.y)*m.forwardVel
        m.slideVelZ = coss(m.faceAngle.y)*m.forwardVel
    end
    
    if m.input & INPUT_Z_DOWN ~= 0 and m.actionTimer > 10 then
        update_speed_cap(m, 3, true)
        m.particleFlags = PARTICLE_FIRE
    else
        update_speed_cap(m, 25)
    end

    -- Ramp physics
    local yVelFloor = get_mario_y_vel_from_floor(m)
    if m.actionTimer > 0 and ((e.yVelStore > 0 and yVelFloor <= 0 and e.yVelStore + yVelFloor > 10) or m.pos.y ~= m.floorHeight) then
        local yVel = e.yVelStore
        e.yVelStore = yVelFloor
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_SLIDE_AIR, 0, yVel)
    else
        e.yVelStore = yVelFloor
    end

    if update_squishy_sliding(m, 4) then
        set_mario_action(m, ACT_SLIDE_KICK_SLIDE_STOP, 0)
    end
    common_slide_action(m, ACT_SLIDE_KICK_SLIDE_STOP, ACT_SQUISHY_SLIDE, MARIO_ANIM_SLIDE_KICK)

    -- Start Water skipping
    if mario_is_on_water(m) then
        m.pos.y = m.pos.y + 10
        set_mario_action_and_y_vel(m, ACT_SQUISHY_SLIDE_AIR, 0, 50)
    end

    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x80, 0x80)
    if m.actionTimer > 0 then
        if m.input & INPUT_A_PRESSED ~= 0 then
            if m.actionArg == 1 then
                set_mario_action(m, ACT_DOUBLE_JUMP, 0)
            else
                set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, 30)
            end
        end
        if m.input & INPUT_B_PRESSED ~= 0 then
            if squishy_has_koopa_shell(m) then
                set_mario_action(m, ACT_SQUISHY_RIDING_SHELL_GROUND, 0)
            else
                set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, 30)
            end
        end
        if omm_moveset_enabled(m) and m.controller.buttonPressed & X_BUTTON ~= 0 then
            set_mario_action(m, ACT_OMM_CAPPY_THROW_GROUND, 0)
        end
    end
    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_slide_air(m)
    local e = gSquishyExtraStates[m.playerIndex]
    common_air_action_step(m, ACT_SQUISHY_SLIDE, MARIO_ANIM_SLIDE_KICK, AIR_STEP_NONE)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0xF0, 0xF0)
    if m.actionArg == 0 then
        if m.forwardVel > 30 and mario_is_on_water(m) and (m.flags & MARIO_METAL_CAP == 0) then
            set_mario_action_and_y_vel(m, ACT_SQUISHY_SLIDE_AIR, 0, m.forwardVel*0.25)
            m.forwardVel = m.forwardVel - 2
            m.particleFlags = PARTICLE_SHALLOW_WATER_SPLASH
            m.actionTimer = 0
            m.marioObj.header.gfx.angle.x = -0xB0*clamp(m.vel.y, -40, 40)
        end
    else
        --common_air_action_step(m, ACT_SQUISHY_GROUND_POUND_LAND, MARIO_ANIM_SLIDE_KICK, AIR_STEP_NONE)
        m.vel.y = -math.abs(m.forwardVel)
        m.marioObj.header.gfx.angle.x = 0x2000
        m.forwardVel = m.forwardVel + 3
    end
    m.peakHeight = m.pos.y
    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_Z_DOWN ~= 0 then
        m.actionArg = 1
    end
    if m.input & INPUT_A_PRESSED ~= 0 then
        set_mario_action(m, ACT_SQUISHY_ROLLOUT, 0)
    end
end

--- @param m MarioState
local function act_squishy_rollout(m)
    local e = gSquishyExtraStates[m.playerIndex]
    if m.actionTimer == 1 then
        m.vel.x = m.slideVelX
        m.vel.z = m.slideVelZ
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
    common_air_action_step(m, ACT_JUMP_LAND, MARIO_ANIM_FORWARD_SPINNING_FLIP, AIR_STEP_CHECK_LEDGE_GRAB)
    update_omm_air_rotation(m)
    squishy_allow_spin_jump(m, m.actionArg == 0)
    m.peakHeight = m.pos.y
    --m.vel.y = m.vel.y + 0.5
    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_Z_PRESSED ~= 0 and m.actionArg == 0 then
        set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 50)
    end
end

--- @param m MarioState
local function act_squishy_ground_pound(m)
    local e = gSquishyExtraStates[m.playerIndex]
    local anim = MARIO_ANIM_GROUND_POUND
    if m.actionArg == 1 then
        anim = MARIO_ANIM_DIVE
    end
    if m.actionArg == 2 then
        anim = MARIO_ANIM_TWIRL
    end
    common_air_action_step(m, ACT_SQUISHY_GROUND_POUND_LAND, anim, AIR_STEP_CHECK_LEDGE_GRAB)
    update_omm_air_rotation(m)
    -- setup when action starts (horizontal speed and voiceline)
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_WAH2)
        e.gfxAnimY = 0
    end
    e.groundPoundFromRollout = true
    e.gfxAnimY = e.gfxAnimY + math.min(math.abs(m.vel.y*0.8), 100)
    m.marioObj.header.gfx.angle.y = m.faceAngle.y + e.gfxAnimY*0x80
    if m.actionArg == 1 then
        m.marioObj.header.gfx.angle.x = 0x4000*clamp(-m.vel.y + 60, 0, 60)/50
    else
        if omm_moveset_enabled(m) and m.input & INPUT_B_PRESSED ~= 0 then
            m.faceAngle.y = m.intendedYaw
            m.forwardVel = m.forwardVel + 15
            set_mario_action_and_y_vel(m, ACT_SQUISHY_DIVE, 0, 30)
        end
    end
    if m.actionArg == 2 then -- OMM
        m.vel.x = 0
        m.vel.z = 0
        m.forwardVel = 0
        m.particleFlags = PARTICLE_SPARKLES
    end
    e.yVelStore = m.vel.y
    m.actionTimer = m.actionTimer + 1
    m.peakHeight = m.pos.y
    m.forwardVel = m.forwardVel*1.01
    if m.input & INPUT_A_PRESSED ~= 0 and m.input & INPUT_Z_DOWN == 0 then
        m.faceAngle.y = m.intendedYaw
        m.forwardVel = math.abs(m.forwardVel)
        e.groundpoundCancels = e.groundpoundCancels + 1
        set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 1, 30)
    end
end

--- @param m MarioState
local function act_squishy_ground_pound_gravity(m)
    m.vel.y = math.max(m.vel.y - 7, -300)
end

--- @param m MarioState
local function act_squishy_ground_pound_land(m)
    local e = gSquishyExtraStates[m.playerIndex]
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_HAHA)
        --play_mario_heavy_landing_sound(m)
        e.forwardVelStore = m.forwardVel
        m.particleFlags = PARTICLE_HORIZONTAL_STAR | PARTICLE_MIST_CIRCLE
        set_environmental_camera_shake(SHAKE_ENV_EXPLOSION)
    end
    m.forwardVel = 0
    m.vel.x = 0
    m.vel.y = 0
    common_landing_action(m, MARIO_ANIM_GROUND_POUND_LANDING, ACT_FREEFALL)
    squishy_allow_spin_jump(m)
    
    m.forwardVel = 0

    m.actionTimer = m.actionTimer + 1
    if m.actionTimer > 10 then
        set_mario_action(m, ACT_IDLE, 0)
        e.groundPoundJump = true
    else
        if m.input & INPUT_A_PRESSED ~= 0 then
            local speedBalanced = math.sqrt(e.yVelStore * e.yVelStore + e.forwardVelStore * e.forwardVelStore)
            if m.input & INPUT_NONZERO_ANALOG ~= 0 then
                m.vel.y = 60
                m.forwardVel = speedBalanced*0.6
            else
                m.vel.y = math.max(speedBalanced*0.65, 70)
                m.forwardVel = speedBalanced*0.1
            end
            set_mario_action(m, ACT_SQUISHY_GROUND_POUND_JUMP, 0)
            m.faceAngle.y = m.intendedYaw
        end
        if (m.input & INPUT_B_PRESSED ~= 0) then
            m.faceAngle.y = m.intendedYaw
            m.forwardVel = math.sqrt(e.yVelStore * e.yVelStore + e.forwardVelStore * e.forwardVelStore)*0.7
            set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
            e.groundPoundJump = true
        end
    end
end

--- @param m MarioState
local function act_squishy_ground_pound_jump(m)
    local e = gSquishyExtraStates[m.playerIndex]
    common_air_action_step(m, ACT_JUMP_LAND, CHAR_ANIM_SINGLE_JUMP, AIR_STEP_CHECK_LEDGE_GRAB)
    update_omm_air_rotation(m)
    squishy_allow_midair_spin(m)
    squishy_allow_spin_jump(m)
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_YAHOO_WAHA_YIPPEE)
        e.gfxAnimY = 0x20000
    end
    if e.gfxAnimY > 1 then
        e.gfxAnimY = e.gfxAnimY*0.8
        m.marioObj.header.gfx.angle.y = m.faceAngle.y + e.gfxAnimY
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
    local e = gSquishyExtraStates[m.playerIndex]
    perform_air_step(m, AIR_STEP_NONE)
    set_mario_animation(m, MARIO_ANIM_START_WALLKICK)

    if m.actionTimer == 0 then
        e.forwardVelStore = m.forwardVel
        if m.wall ~= nil then
            e.prevWallAngle = atan2s(m.wall.normal.z, m.wall.normal.x)
        end
    end

    m.vel.y = clamp_soft(m.vel.y + 0.3, -70, 150, 2)
    m.particleFlags = PARTICLE_DUST
    if m.wall == nil then
        m.faceAngle.y = e.prevWallAngle
        if m.pos.y == m.floorHeight and e.prevFloorDist < 100 then
            set_mario_action(m, ACT_FREEFALL_LAND, 0)
        else
            m.faceAngle.y = m.faceAngle.y + 0x8000
            set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, m.vel.y)
            m.pos.y = m.pos.y + 10
            m.forwardVel = m.forwardVel * 0.4
        end
    else
        local wallAngle = atan2s(m.wall.normal.z, m.wall.normal.x)
        local wallAngleDiff = (wallAngle - e.prevWallAngle)
        if wallAngleDiff ~= 0 and (wallAngleDiff < 0x3000 and wallAngleDiff > -0x3000) then
            local vel = math.sqrt(m.vel.z^2 + m.vel.x^2)
            local velAngle = atan2s(m.vel.z, m.vel.x)
            velAngle = velAngle + wallAngleDiff
            m.vel.x = vel * sins(velAngle)
            m.vel.z = vel * coss(velAngle)
        end
        e.prevWallAngle = wallAngle
        m.marioObj.header.gfx.angle.y = atan2s(m.wall.normal.z, m.wall.normal.x)
        e.prevFloorDist = m.pos.y - m.floorHeight
        play_sound(SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, m.marioObj.header.gfx.cameraToObject);
    end
    
    if m.input & INPUT_A_PRESSED ~= 0 then
        m.faceAngle.y = e.prevWallAngle

        play_sound((m.flags & MARIO_METAL_CAP ~= 0) and SOUND_ACTION_METAL_BONK or SOUND_ACTION_BONK,
                m.marioObj.header.gfx.cameraToObject);

        set_mario_action(m, ACT_SQUISHY_WALL_KICK_AIR, 0)
    end

    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_fire_burn(m)
    local e = gSquishyExtraStates[m.playerIndex]
    common_air_action_step(m, ACT_SQUISHY_FIRE_BURN, MARIO_ANIM_FIRE_LAVA_BURN, AIR_STEP_NONE)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x300, 0x300)
    m.peakHeight = m.pos.y

    if m.pos.y == m.floorHeight and m.vel.y < 50 then
        m.vel.y = 50
    end
    

    m.actionTimer = m.actionTimer + 1

    if (m.health < 0x100) then
        if (m.playerIndex ~= 0) then
            -- never kill remote marios
            m.health = 0x100;
        else
            if (mario_can_bubble(m)) then
                m.health = 0xFF;
                mario_set_bubbled(m);
            else
                level_trigger_warp(m, WARP_OP_DEATH);
            end
        end
        update_spam_burnout(m, 0)
    elseif update_spam_burnout(m) <= 0 then
        set_mario_action(m, ACT_FREEFALL, 0)
    end

    m.marioBodyState.eyeState = MARIO_EYES_DEAD;
end

--[[
--- @param m MarioState
local function update_mario_water_health(m)
    if (m.area.terrainType & TERRAIN_MASK) == TERRAIN_SNOW then
        m.health = m.health - 3
    else
        if (m.pos.y >= (m.waterLevel - 140)) then
            m.health = m.health + 0x1A;
        else
            m.health = m.health - 1
        end
    end
end
]]

--- @param m MarioState
local function act_squishy_swim_idle(m)
    local e = gSquishyExtraStates[m.playerIndex]
    perform_water_step(m)
    set_mario_animation(m, MARIO_ANIM_WATER_IDLE)
    --update_mario_water_health(m)

    m.vel.x = clamp_soft(m.vel.x, 0, 0, 1)
    m.vel.y = clamp_soft(m.vel.y, 0, 0, 1)
    m.vel.z = clamp_soft(m.vel.z, 0, 0, 1)

    if m.input & INPUT_NONZERO_ANALOG ~= 0 or m.input & INPUT_A_DOWN ~= 0 or m.input & INPUT_Z_DOWN ~= 0 then
        set_mario_action(m, ACT_SQUISHY_SWIM_MOVING, 0)
    end
    m.faceAngle.x = clamp_soft(m.faceAngle.x, 0, 0, 0x200)
    

    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_swim_moving(m)
    local e = gSquishyExtraStates[m.playerIndex]
    perform_water_step(m)
    set_mario_animation(m, MARIO_ANIM_FLUTTERKICK)
    --update_mario_water_health(m)

    if m.actionTimer == 0 then
        m.forwardVel = math.sqrt(m.vel.x^2 + m.vel.y^2 + m.vel.z^2)
        m.faceAngle.x = atan2s(m.forwardVel, m.vel.y)
    end

    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x300, 0x300)

    if m.input & INPUT_NONZERO_ANALOG ~= 0 or m.input & INPUT_A_DOWN ~= 0 or m.input & INPUT_Z_DOWN ~= 0 then
        if m.forwardVel < 25 then
            m.forwardVel = m.forwardVel + 1
        elseif m.forwardVel > 30 then
            m.forwardVel = m.forwardVel - 2
        end
        m.faceAngle.x = clamp_soft(m.faceAngle.x, 0, 0, 0x100)
    else
        m.forwardVel = m.forwardVel - 3
        if m.forwardVel < 10 then
            set_mario_action(m, ACT_SQUISHY_SWIM_IDLE, 0)
        end
    end
    
    if m.input & INPUT_B_PRESSED ~= 0 then
        return set_mario_action(m, ACT_SQUISHY_SWIM_ATTACK, 0)
    end

    if m.input & INPUT_A_DOWN ~= 0 then
        m.faceAngle.x = math.min(m.faceAngle.x + 0x400, 0x3000)
    end

    if m.input & INPUT_Z_DOWN ~= 0 then
        m.faceAngle.x = math.max(m.faceAngle.x - 0x400, -0x3000)
    end

    m.vel.x = m.forwardVel * sins(m.faceAngle.y) * coss(m.faceAngle.x)
    m.vel.y = m.forwardVel * sins(m.faceAngle.x)
    m.vel.z = m.forwardVel * coss(m.faceAngle.y) * coss(m.faceAngle.x)
    

    m.actionTimer = m.actionTimer + 1
    apply_water_current(m, m.vel)
end

--- @param m MarioState
local function act_squishy_swim_attack(m)
    local e = gSquishyExtraStates[m.playerIndex]
    perform_water_step(m)
    set_mario_animation(m, MARIO_ANIM_FORWARD_SPINNING)
    --update_mario_water_health(m)

    if m.actionTimer == 0 then
        m.forwardVel = m.forwardVel + 10
        e.gfxAnimZ = 0x10000
    end

    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x100, 0x100)

    if m.input & INPUT_A_DOWN ~= 0 then
        m.faceAngle.x = math.min(m.faceAngle.x + 0x100, 0x3000)
    end

    if m.input & INPUT_Z_DOWN ~= 0 then
        m.faceAngle.x = math.max(m.faceAngle.x - 0x100, -0x3000)
    end

    m.vel.x = m.forwardVel * sins(m.faceAngle.y) * coss(m.faceAngle.x)
    m.vel.y = m.forwardVel * sins(m.faceAngle.x)
    m.vel.z = m.forwardVel * coss(m.faceAngle.y) * coss(m.faceAngle.x)

    if m.actionTimer > 15 then
        set_mario_action(m, ACT_SQUISHY_SWIM_IDLE, 0)
    end

    if (m.pos.y >= (m.waterLevel - 140) and m.faceAngle.x > 0x100) then
        m.pos.y = m.waterLevel
        m.forwardVel = math.sqrt(m.vel.x^2 + m.vel.z^2)
        m.vel.y = math.max(m.vel.y, 50)
        set_mario_action(m, ACT_SQUISHY_ROLLOUT, 1)
    end
    

    m.actionTimer = m.actionTimer + 1
    apply_water_current(m, m.vel)
end

local function act_squishy_wall_kick_air(m)
    if m.actionTimer == 1 then
        m.forwardVel = math.max(35, math.abs(m.vel.y*0.7)) --math.abs(e.forwardVelStore*0.8)
        m.vel.y = math.max(m.vel.y*0.7, 40)
    end

    if (m.input & INPUT_B_PRESSED ~= 0) then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0);
    end

    if (m.input & INPUT_Z_PRESSED ~= 0) then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60);
    end

    play_mario_jump_sound(m);
    common_air_action_step(m, ACT_JUMP_LAND, MARIO_ANIM_SLIDEJUMP, AIR_STEP_CHECK_LEDGE_GRAB);
    m.actionTimer = m.actionTimer + 1
end

local function act_squishy_side_flip(m)
    if m.actionTimer == 0 then
        m.vel.y = math.max(math.abs(m.forwardVel), 60)
        m.forwardVel = 20
        m.faceAngle.y = convert_s16(m.faceAngle.y + 0x8000)
    end

    if (m.input & INPUT_B_PRESSED ~= 0) then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0);
    end

    if (m.input & INPUT_Z_PRESSED ~= 0) then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60);
    end

    play_mario_jump_sound(m);

    if (common_air_action_step(m, ACT_SIDE_FLIP_LAND, MARIO_ANIM_SLIDEFLIP, AIR_STEP_CHECK_LEDGE_GRAB) ~= AIR_STEP_GRABBED_LEDGE) then
        m.marioObj.header.gfx.angle.y = m.marioObj.header.gfx.angle.y + 0x8000;
    end

    m.actionTimer = m.actionTimer + 1
end

local function act_squishy_ledge_grab(m)
    local e = gSquishyExtraStates[m.playerIndex]
    local heightAboveFloor;
    local intendedDYaw = convert_s16(m.intendedYaw - m.faceAngle.y);
    local hasSpaceForMario = (m.ceilHeight - m.floorHeight >= 160.0);

    if m.actionTimer == 1 then
        e.forwardVelStore = math.max(math.sqrt(m.forwardVel^2 + m.vel.y^2), 30)
    end

    -- Remove false ledge grabs
    --[[
    if (m.floor.normal.y < 0.9063078) then
        return let_go_of_ledge(m);
    end
    ]]    

    if (m.input & (INPUT_Z_PRESSED | INPUT_OFF_FLOOR) ~= 0) then
        return let_go_of_ledge(m);
    end

    if ((m.input & INPUT_A_PRESSED ~= 0) and hasSpaceForMario) then
        m.forwardVel = e.forwardVelStore*0.3
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 0, e.forwardVelStore*0.7);
    end

    if ((m.input & INPUT_B_PRESSED ~= 0) and hasSpaceForMario) then
        m.forwardVel = e.forwardVelStore*0.8
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 0);
    end

    --[[
    if (m.input & INPUT_STOMPED ~= 0) then
        if (m.marioObj.oInteractStatus & INT_STATUS_MARIO_KNOCKBACK_DMG ~= 0) then
            m.hurtCounter = m.hurtCounter + (m.flags & MARIO_CAP_ON_HEAD ~= 0) and 12 or 18;
        end
        return let_go_of_ledge(m);
    end
    ]]

    if (m.actionTimer == 10 and (m.input & INPUT_NONZERO_ANALOG ~= 0)) then
        if (intendedDYaw >= -0x4000 and intendedDYaw <= 0x4000) then
            if (hasSpaceForMario) then
                return set_mario_action(m, ACT_LEDGE_CLIMB_SLOW_1, 0);
            end
        else
            return let_go_of_ledge(m);
        end
    end

    heightAboveFloor = m.pos.y - find_floor_height_relative_polar(m, -0x8000, 30.0);
    if (hasSpaceForMario and heightAboveFloor < 100.0) then
        return set_mario_action(m, ACT_LEDGE_CLIMB_FAST, 0);
    end

    if (m.actionArg == 0) then
        play_sound_if_no_flag(m, SOUND_MARIO_WHOA, MARIO_MARIO_SOUND_PLAYED);
    end

    stop_and_set_height_to_floor(m);
    set_mario_animation(m, MARIO_ANIM_IDLE_ON_LEDGE);

    m.actionTimer = m.actionTimer + 1;
    e.forwardVelStore = math.max(e.forwardVelStore*0.95, 30)
    return 0;
end

hook_mario_action(ACT_SQUISHY_WALKING, { every_frame = act_squishy_walking})
hook_mario_action(ACT_SQUISHY_CROUCH_SLIDE, { every_frame = act_squishy_crouch_slide})
hook_mario_action(ACT_SQUISHY_DIVE, { every_frame = act_squishy_dive}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_DIVE_SLIDE, { every_frame = act_squishy_dive_slide}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_LONG_JUMP, { every_frame = act_squishy_long_jump})
hook_mario_action(ACT_SQUISHY_SLIDE, { every_frame = act_squishy_slide}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_SLIDE_AIR, { every_frame = act_squishy_slide_air})
hook_mario_action(ACT_SQUISHY_ROLLOUT, act_squishy_rollout)
hook_mario_action(ACT_SQUISHY_GROUND_POUND, { every_frame = act_squishy_ground_pound, gravity = act_squishy_ground_pound_gravity}, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_GROUND_POUND_JUMP, { every_frame = act_squishy_ground_pound_jump})
hook_mario_action(ACT_SQUISHY_GROUND_POUND_LAND, act_squishy_ground_pound_land, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_WALL_SLIDE, {every_frame = act_squishy_wall_slide})
hook_mario_action(ACT_SQUISHY_FIRE_BURN, {every_frame = act_squishy_fire_burn})
hook_mario_action(ACT_SQUISHY_SWIM_IDLE, {every_frame = act_squishy_swim_idle})
hook_mario_action(ACT_SQUISHY_SWIM_MOVING, {every_frame = act_squishy_swim_moving})
hook_mario_action(ACT_SQUISHY_SWIM_ATTACK, {every_frame = act_squishy_swim_attack}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_WALL_KICK_AIR, act_squishy_wall_kick_air)
hook_mario_action(ACT_SQUISHY_SIDE_FLIP, act_squishy_side_flip)
hook_mario_action(ACT_SQUISHY_LEDGE_GRAB, act_squishy_ledge_grab)

-------------------------
-- Object Interactions --
-------------------------

local shellSpeed = 1.0

local function race_get_slope_physics(m)
    local friction = 0.96
    local force = 3

    if mario_floor_is_slope(m) ~= 0 then
        local slopeClass = 0

        if m.action ~= ACT_SOFT_BACKWARD_GROUND_KB and m.action ~= ACT_SOFT_FORWARD_GROUND_KB then
            slopeClass = mario_get_floor_class(m)
        end

        if slopeClass == SURFACE_CLASS_VERY_SLIPPERY then
            friction = 0.98
            force = 3.3
        elseif slopeClass == SURFACE_CLASS_SLIPPERY then
            friction = 0.97
            force = 3.2
        end
    end

    return {
        force = force,
        friction = friction,
    }
end

local function race_apply_slope_accel(m)
    local physics = race_get_slope_physics(m)

    local floor = m.floor
    local floorNormal = m.floor.normal

    local mTheta = m.faceAngle.y
    local mSpeed = m.forwardVel * 1.5 * shellSpeed
    if mSpeed > 135 * shellSpeed then mSpeed = 135 * shellSpeed end

    local mDir = {
        x = sins(mTheta),
        y = 0,
        z = coss(mTheta)
    }

    m.slideYaw = m.faceAngle.y
    m.slideVelX = 0
    m.slideVelZ = 0

    -- apply direction
    local angle = vec3f_angle_between(m.vel, mDir)

    local parallel = vec3f_project(m.vel, mDir)
    local perpendicular = { x = m.vel.x - parallel.x, y = m.vel.y - parallel.y, z = m.vel.z - parallel.z }
    local parallelMag = vec3f_length(parallel)
    local perpendicularMag = vec3f_length(perpendicular)
    local originalPerpendicularMag = perpendicularMag

    if angle >= math.pi / 2 then
        parallelMag = -1
    elseif parallelMag < mSpeed then
        local lastMag = parallelMag
        parallelMag = parallelMag * 0.85 + mSpeed * 0.15
        perpendicularMag = perpendicularMag - (parallelMag - lastMag) * 0.12
        if perpendicularMag < 0 then perpendicularMag = 0 end
    end

    vec3f_normalize(parallel)
    vec3f_normalize(perpendicular)
    vec3f_non_nan(parallel)
    vec3f_non_nan(perpendicular)

    local combined = {
        x = parallel.x * parallelMag + perpendicular.x * perpendicularMag,
        y = parallel.y * parallelMag + perpendicular.y * perpendicularMag,
        z = parallel.z * parallelMag + perpendicular.z * perpendicularMag,
    }
    m.vel.x = combined.x
    m.vel.z = combined.z

    -- apply friction
    m.vel.x = m.vel.x * physics.friction
    m.vel.z = m.vel.z * physics.friction
    m.vel.y = 0.0

    -- apply slope
    m.vel.x = m.vel.x + physics.force * floorNormal.x
    m.vel.z = m.vel.z + physics.force * floorNormal.z

    -- apply vanilla forces
    local velBeforeVanilla = { x = m.vel.x, y = m.vel.y, z = m.vel.z }
    mario_update_moving_sand(m)
    mario_update_windy_ground(m)
    m.vel.x = m.vel.x * 0.2 + velBeforeVanilla.x * 0.8
    m.vel.y = m.vel.y * 0.2 + velBeforeVanilla.y * 0.8
    m.vel.z = m.vel.z * 0.2 + velBeforeVanilla.z * 0.8
end

local function update_race_shell_speed(m)
    local maxTargetSpeed = 0
    local targetSpeed = 0
    local startForwardVel = m.forwardVel

    -- brake
    if (m.controller.buttonDown & B_BUTTON) ~= 0 then
        m.forwardVel = m.forwardVel * 0.9
    end

    -- set water level
    if m.floorHeight < m.waterLevel then
        m.floorHeight = m.waterLevel
        m.floor = get_water_surface_pseudo_floor()
        m.floor.originOffset = m.waterLevel -- Negative origin offset
    end

    -- set max target speed
    if m.floor ~= nil and m.floor.type == SURFACE_SLOW then
        maxTargetSpeed = 48.0
    else
        maxTargetSpeed = 64.0
    end

    -- set target speed
    targetSpeed = m.intendedMag * 2.0
    if targetSpeed > maxTargetSpeed then
        targetSpeed = maxTargetSpeed
    end
    if targetSpeed < 18.0 then
        targetSpeed = 18.0
    end

    -- set speed
    if m.forwardVel <= 0.0 then
        m.forwardVel = 1.1

    elseif m.forwardVel <= targetSpeed + 1.1 then
        m.forwardVel = m.forwardVel + 1.1

    elseif m.forwardVel > targetSpeed - 1.5 then
        m.forwardVel = m.forwardVel - 1.5

    elseif m.floor ~= nil and m.floor.normal.y >= 0.95 then
        m.forwardVel = m.forwardVel - 1.1
    end

    if m.forwardVel > 64.0 then
        if m.forwardVel > startForwardVel - 3.0 then
            m.forwardVel = startForwardVel - 3.0
        end
    end

    local turnSpeed = 0x800
    if (m.controller.buttonDown & B_BUTTON) ~= 0 then turnSpeed = 0x650 end
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, turnSpeed, turnSpeed)

    race_apply_slope_accel(m)
end

ACT_SQUISHY_RIDING_SHELL_GROUND = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL)
ACT_SQUISHY_RIDING_SHELL_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL | ACT_FLAG_CONTROL_JUMP_HEIGHT)
ACT_SQUISHY_RIDING_SHELL_FALL = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL)

local function act_race_shell_ground(m)
    local e = gSquishyExtraStates[m.playerIndex]
    if m.actionTimer < 5 then m.actionTimer = m.actionTimer + 1 end

    local startYaw = m.faceAngle.y

    -- enforce min velocities
    if m.forwardVel == 0 then m.forwardVel = 1 end
    if vec3f_length(m.vel) == 0 then m.vel.x = 1 end

    -- jump
    if (m.input & INPUT_A_PRESSED) ~= 0 then
        m.vel.x = m.vel.x * 0.9
        m.vel.z = m.vel.z * 0.9
        m.vel.y = math.max(50 + get_mario_y_vel_from_floor(m)*1, 20)
        return set_mario_action(m, ACT_SQUISHY_RIDING_SHELL_JUMP, 0)
    end
    
    -- Dismount
    if (m.input & INPUT_Z_PRESSED) ~= 0 then
        mario_stop_riding_object(m)
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_ROLLOUT, 1, 30)
    end

    -- update physics
    update_race_shell_speed(m)

    -- set animation
    if m.actionArg == 0 then
        set_mario_animation(m, MARIO_ANIM_START_RIDING_SHELL)
    else
        set_mario_animation(m, MARIO_ANIM_RIDING_SHELL)
    end

    local gs = perform_ground_step(m)
    if gs == GROUND_STEP_LEFT_GROUND then
        m.vel.y = (m.pos.y - e.lastShellY)
        return set_mario_action(m, ACT_SQUISHY_RIDING_SHELL_FALL, 0)

    elseif gs == GROUND_STEP_HIT_WALL then
        -- check if the wall is in the facing direction
        local castDir = {
            x = sins(m.faceAngle.y) * 200,
            y = 0,
            z = coss(m.faceAngle.y) * 200
        }
        local info = collision_find_surface_on_ray(
                m.pos.x, m.pos.y + 100, m.pos.z,
                castDir.x, castDir.y, castDir.z)
        if info.surface ~= nil then
            squishy_has_koopa_shell(m, true)
            mario_stop_riding_object(m)
            play_sound(SOUND_ACTION_BONK, m.marioObj.header.gfx.cameraToObject)
            m.particleFlags = m.particleFlags | PARTICLE_VERTICAL_STAR
            m.forwardVel = 0
            set_mario_action(m, ACT_BACKWARD_GROUND_KB, 0)
        end
    end

    tilt_body_ground_shell(m, startYaw)

    if m.floor.type == SURFACE_BURNING then
        play_sound(SOUND_MOVING_RIDING_SHELL_LAVA, m.marioObj.header.gfx.cameraToObject)
    else
        play_sound(SOUND_MOVING_TERRAIN_RIDING_SHELL, m.marioObj.header.gfx.cameraToObject)
    end

    adjust_sound_for_speed(m)

    reset_rumble_timers(m)
    e.lastShellY = m.pos.y
    return 0
end

function act_race_shell_air(m)
    local e = gSquishyExtraStates[m.playerIndex]
    if m.actionTimer < 5 then m.actionTimer = m.actionTimer + 1 end

    play_mario_sound(m, SOUND_ACTION_TERRAIN_JUMP, 0)
    set_mario_animation(m, MARIO_ANIM_JUMP_RIDING_SHELL)

    --if m.vel.y > 65 then m.vel.y = 65 end

    -- Dismount
    if (m.input & INPUT_Z_PRESSED) ~= 0 then
        mario_stop_riding_object(m)
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 0, 60)
    end

    local mSpeed = m.forwardVel / 128.0 * shellSpeed
    if mSpeed > 100 * shellSpeed then mSpeed = 100 * shellSpeed end
    local mDir = {
        x = sins(m.intendedYaw),
        y = 0,
        z = coss(m.intendedYaw)
    }

    -- apply direction
    local parallel = vec3f_project(mDir, m.vel)
    local perpendicular = { x = mDir.x - parallel.x, y = mDir.y - parallel.y, z = mDir.z - parallel.z }
    local parallelMag = vec3f_length(parallel)
    if parallelMag < mSpeed then parallelMag = mSpeed / parallelMag end

    local combined = {
        x = parallel.x * parallelMag + perpendicular.x * 0.95,
        y = parallel.y * parallelMag + perpendicular.y * 0.95,
        z = parallel.z * parallelMag + perpendicular.z * 0.95,
    }

    m.vel.x = m.vel.x + mSpeed * mDir.x
    m.vel.z = m.vel.z + mSpeed * mDir.z

    -- apply rotation
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x300, 0x300)

    local step = perform_air_step(m, 0)
    if step == AIR_STEP_LANDED then
        set_mario_action(m, ACT_RIDING_SHELL_GROUND, 1)
    elseif step == AIR_STEP_HIT_WALL then
        mario_set_forward_vel(m, 0.0)
    elseif step == AIR_STEP_HIT_LAVA_WALL then
        lava_boost_on_wall(m)
    end

    m.marioObj.header.gfx.pos.y = m.marioObj.header.gfx.pos.y + 42.0
    e.lastShellY = m.pos.y
    return 0
end

hook_mario_action(ACT_SQUISHY_RIDING_SHELL_GROUND, { every_frame = act_race_shell_ground }, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_RIDING_SHELL_JUMP, { every_frame = act_race_shell_air }, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_RIDING_SHELL_FALL, { every_frame = act_race_shell_air }, INT_FAST_ATTACK_OR_SHELL)

local hitActs = {
    [ACT_BACKWARD_AIR_KB] = true,
    [ACT_FORWARD_AIR_KB] = true,
    [ACT_BACKWARD_GROUND_KB] = true,
    [ACT_FORWARD_GROUND_KB] = true,
    [ACT_HARD_FORWARD_GROUND_KB] = true,
    [ACT_HARD_BACKWARD_GROUND_KB] = true,
    [ACT_SOFT_FORWARD_GROUND_KB] = true,
    [ACT_SOFT_BACKWARD_GROUND_KB] = true,
}

local function squishy_update(m)
    local e = gSquishyExtraStates[m.playerIndex]
    e.panicking = false
    if m.action & ACT_FLAG_AIR == 0 then
        e.groundpoundCancels = 0
    end
    m.vel.y = m.vel.y - math.max(e.groundpoundCancels - 1, 0)*0.6

    if (m.action == ACT_SQUISHY_LONG_JUMP or m.action == ACT_SQUISHY_DIVE) and m.input & INPUT_Z_PRESSED ~= 0 then
        set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, (m.action == ACT_SQUISHY_DIVE and 1 or 0), 60)
    end
    if m.action == ACT_BUTT_SLIDE then
        set_mario_action(m, ACT_SQUISHY_SLIDE, 1)
    end
    if m.action == ACT_SLIDE_KICK then
        m.forwardVel = m.forwardVel + 30
        set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end
    if (m.action == ACT_PUNCHING or m.action == ACT_MOVE_PUNCHING) and m.actionArg == 9 then
        m.forwardVel = 70
        set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end
    if m.pos.y == m.floorHeight and m.action ~= ACT_SQUISHY_GROUND_POUND_LAND and m.action ~= ACT_SQUISHY_GROUND_POUND_JUMP then
        e.groundPoundJump = true
    end
    if m.action == ACT_SPAWN_SPIN_AIRBORNE or m.action == ACT_SPAWN_NO_SPIN_AIRBORNE then
        m.pos.y = math.min(math.max(m.pos.y - m.floorHeight, 1000) + m.floorHeight, m.ceilHeight - 150) -- Force spawn height
        set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 1)
    end
    if update_spam_burnout(m) > 0 then
        if (m.flags & MARIO_METAL_CAP == 0) then
            m.particleFlags = PARTICLE_FIRE
            m.health = m.health - 10
        end
        play_sound(SOUND_AIR_BLOW_FIRE, m.pos)
        if (m.input & INPUT_A_PRESSED ~= 0 or m.input & INPUT_B_PRESSED ~= 0 or m.input & INPUT_Z_PRESSED ~= 0) then
            update_spam_burnout(m, e.spamBurnout - 2)
            play_sound(SOUND_GENERAL_FLAME_OUT, m.pos)
        end
        if (m.waterLevel ~= nil and m.pos.y < m.waterLevel) then
            play_sound(SOUND_GENERAL_FLAME_OUT, m.pos)
            update_spam_burnout(m, 0)
        end
        update_spam_burnout(m, e.spamBurnout - 1)
        e.panicking = true
    end

    if m.health <= 0x300 then
        e.panicking = true
    end

    if m.marioObj.header.gfx.animInfo.animID == CHAR_ANIM_RUNNING then
        if m.forwardVel >= 50 then
            smlua_anim_util_set_animation(m.marioObj, SQUISHY_ANIM_RUN)
            if not squishy_has_koopa_shell(m) then
                m.marioBodyState.handState = MARIO_HAND_OPEN
            end
        elseif smlua_anim_util_get_current_animation_name(m.marioObj) == SQUISHY_ANIM_RUN then
            m.marioObj.header.gfx.animInfo.animID = -1
        end
    end

    if hitActs[m.action] then
        squishy_has_koopa_shell(m, false)
    end
end

---@param m MarioState
local function squishy_before_action(m, nextAct)
    local e = gSquishyExtraStates[m.playerIndex]

    if nextAct == ACT_WALKING then
        if not e.forceDefaultWalk then
            return set_mario_action(m, ACT_SQUISHY_WALKING, 0)
        else
            e.forceDefaultWalk = false
        end
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
    if m.wall ~= nil and nextAct == ACT_AIR_HIT_WALL or nextAct == ACT_OMM_WALL_SLIDE then
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_WALL_SLIDE, 0, m.forwardVel*0.9 + m.vel.y*0.7)
    end
    if nextAct == ACT_LONG_JUMP and m.forwardVel > 0 then
        return set_mario_action(m, ACT_SQUISHY_LONG_JUMP, 0)
    end
    if (nextAct == ACT_BURNING_FALL or nextAct == ACT_BURNING_GROUND or nextAct == ACT_BURNING_JUMP or nextAct == ACT_LAVA_BOOST) and m.health > 255 then
        update_spam_burnout(m, spamBurnoutMax)
        m.hurtCounter = 0
        return set_mario_action_and_y_vel(m, ACT_SQUISHY_FIRE_BURN, 0, 90)
    end
    if omm_moveset_enabled(m) then
        if nextAct == ACT_OMM_SPIN_POUND then
            return set_mario_action_and_y_vel(m, ACT_SQUISHY_GROUND_POUND, 2, -70)
        end
        if nextAct == ACT_OMM_ROLL then
            return set_mario_action(m, ACT_SQUISHY_SLIDE, 2)
        end
    end
    if nextAct == ACT_CROUCH_SLIDE then
        return set_mario_action(m, ACT_SQUISHY_CROUCH_SLIDE, 0)
    end
    if nextAct == ACT_BUTT_SLIDE_AIR then
        return set_mario_action(m, ACT_SQUISHY_SLIDE_AIR, 0)
    end
    if nextAct == ACT_RIDING_SHELL_GROUND then
        squishy_has_koopa_shell(m, true)
        return set_mario_action(m, ACT_SQUISHY_RIDING_SHELL_GROUND, 0)
    end
    if (m.flags & MARIO_METAL_CAP == 0) then
        if nextAct == ACT_WATER_IDLE then
            return set_mario_action(m, ACT_SQUISHY_SWIM_IDLE, 0)
        end
        if nextAct == ACT_WATER_PLUNGE then
            return set_mario_action(m, ACT_SQUISHY_SWIM_MOVING, 0)
        end
    end
    if nextAct == ACT_WALL_KICK_AIR then
        return set_mario_action(m, ACT_SQUISHY_WALL_KICK_AIR, 0)
    end
    if nextAct == ACT_SIDE_FLIP then
        return set_mario_action(m, ACT_SQUISHY_SIDE_FLIP, 0)
    end
    if nextAct == ACT_LEDGE_GRAB then
        return set_mario_action(m, ACT_SQUISHY_LEDGE_GRAB, 0)
    end
end

local strainingActs = {
    [ACT_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_SQUISHY_ROLLOUT] = true,
    [ACT_SQUISHY_DIVE] = true,
    [ACT_SQUISHY_GROUND_POUND_JUMP] = true,
    [ACT_SQUISHY_LONG_JUMP] = true,
}

local canWallkick = {
    [ACT_JUMP] = ACT_JUMP,
    [ACT_HOLD_JUMP] = ACT_HOLD_JUMP,
    [ACT_DOUBLE_JUMP] = ACT_DOUBLE_JUMP,
    [ACT_TRIPLE_JUMP] = ACT_TRIPLE_JUMP,
    [ACT_SIDE_FLIP] = ACT_SIDE_FLIP,
    [ACT_BACKFLIP] = ACT_BACKFLIP,
    [ACT_SQUISHY_LONG_JUMP] = ACT_SQUISHY_LONG_JUMP,
    [ACT_SQUISHY_WALL_KICK_AIR] = ACT_SQUISHY_WALL_KICK_AIR,
    [ACT_TOP_OF_POLE_JUMP] = ACT_TOP_OF_POLE_JUMP,
    [ACT_FREEFALL] = ACT_FREEFALL,
    
    [ACT_SQUISHY_DIVE] = ACT_SQUISHY_DIVE,
    [ACT_SQUISHY_GROUND_POUND] = ACT_SQUISHY_GROUND_POUND,
    [ACT_SQUISHY_GROUND_POUND_JUMP] = ACT_SQUISHY_GROUND_POUND_JUMP,
    [ACT_SQUISHY_ROLLOUT] = ACT_SQUISHY_ROLLOUT,
}

local wallAngleLimit = 70
local function squishy_before_phys_step(m)
    local e = gSquishyExtraStates[m.playerIndex]

    -- Straining
    if strainingActs[m.action] and m.action & ACT_FLAG_SWIMMING_OR_FLYING == 0 and m.pos.y > m.floorHeight then
        if m.input & INPUT_NONZERO_ANALOG ~= 0 then
            e.intendedDYaw = m.intendedYaw - m.faceAngle.y
            e.intendedMag = m.intendedMag / 32;
            e.sidewaysSpeed = e.intendedMag * sins(e.intendedDYaw) * m.forwardVel*0.22
        end
        m.vel.x = m.vel.x + e.sidewaysSpeed * sins(m.faceAngle.y + 0x4000);
        m.vel.z = m.vel.z + e.sidewaysSpeed * coss(m.faceAngle.y + 0x4000);
    else
        e.sidewaysSpeed = 0
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
                --mario_bonk_reflection(m, 0);
                m.faceAngle.y = m.faceAngle.y + 0x8000;
                set_mario_action(m, ACT_SQUISHY_WALL_SLIDE, 1)
            end
        end
    end

    if not omm_moveset_enabled(m) then
        -- Peaking Velocity
        if m.action & ACT_FLAG_BUTT_OR_STOMACH_SLIDE == 0 then
            update_speed_cap(m)
        end
    end
end

local function hud_render()
    djui_hud_set_resolution(RESOLUTION_N64)

    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        local e = gSquishyExtraStates[i]

        local width = djui_hud_get_screen_width()
        local height = djui_hud_get_screen_height()

        local burning = update_spam_burnout(m)/spamBurnoutMax
        if burning > 0 then
            local pos = {x = 0, y = 0, z = 0}
            djui_hud_world_pos_to_screen_pos(m.pos, pos)
            pos.x = pos.x + 20
            pos.y = pos.y - 20
            djui_hud_set_color(0, 0, 0, 200)
            djui_hud_render_rect(pos.x, pos.y, 6, 25)
            djui_hud_set_color(255, 20, 0, 255)
            djui_hud_render_rect(pos.x + 1, pos.y + 1, 4, 23*burning)
        end
    end
end

local function level_init()
    update_spam_burnout(gMarioStates[0])
end

local function on_interact(m, obj, type)
    local e = gSquishyExtraStates[m.playerIndex]
    local bhvID = get_id_from_behavior(obj.behavior)
    if (bhvID == id_bhvDoor or bhvID == id_bhvDoorWarp or bhvID == id_bhvStarDoor) and m.action == ACT_SQUISHY_WALKING then
        e.forceDefaultWalk = true
        set_mario_action(m, ACT_WALKING, 0)
    end
    if bhvID == id_bhvKoopaShell and m.action == ACT_SQUISHY_WALKING then
        e.forceDefaultWalk = true
        set_mario_action(m, ACT_WALKING, 0)
    end
end

local grabActions = {
    [ACT_SQUISHY_DIVE] = true,
    [ACT_SQUISHY_DIVE_SLIDE] = true,
    [ACT_SQUISHY_SWIM_ATTACK] = true,
}

local function allow_interact(m, o, intType)
    if grabActions[m.action] then
        if (intType & (INTERACT_GRABBABLE) ~= 0) and o.oInteractionSubtype & (INT_SUBTYPE_NOT_GRABBABLE) == 0 then
            m.interactObj = o
            m.input = m.input | INPUT_INTERACT_OBJ_GRABBABLE
            if o.oSyncID ~= 0 then
                network_send_object(o, true)
            end
        end
    end 
end

local function on_character_select_load()
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_MARIO_UPDATE, squishy_update)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_SET_MARIO_ACTION, squishy_before_action)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_BEFORE_PHYS_STEP, squishy_before_phys_step)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ON_HUD_RENDER_BEHIND, hud_render)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ON_LEVEL_INIT, level_init)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ON_INTERACT, on_interact)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ALLOW_INTERACT, allow_interact)
end
hook_event(HOOK_ON_MODS_LOADED, on_character_select_load)

-- Host Speed Multiplier Setting
local function command_squishy_speed(msg)
    msg = string.lower(msg)
    if msg == "default" then
        gGlobalSyncTable.squishySpeedMult = 1
    elseif msg == "balanced" then
        gGlobalSyncTable.squishySpeedMult = 0.8
    elseif msg == "arena" then
        gGlobalSyncTable.squishySpeedMult = 0.3
    elseif tonumber(msg) ~= nil then
        gGlobalSyncTable.squishySpeedMult = clamp(tonumber(msg), 0.1, 1.5)
    else
        djui_chat_message_create("Please enter a valid number")
        return true
    end
    local speedMult = gGlobalSyncTable.squishySpeedMult
    local speedMultString = "Default"
    if speedMult < 1 then
        if speedMult < 0.5 then
            speedMultString = "Nerfed"
        else
            speedMultString = "Balanced"
        end
    elseif speedMult > 1 then
        speedMultString = "Buffed"
    end
    djui_chat_message_create("Squishy Speed Multiplier set to: " .. speedMultString .. " (" .. speedMult .. ")")
    djui_popup_create_global("Character Select:\nSquishy Speed Multiplier set to:\n" .. speedMultString .. " (" .. speedMult .. ")", 2)
    return true
end

if network_is_server() then
    hook_chat_command("squishy-speed", "Sets a speed multiplier for Squishy's speed between 0.1 and 1.5", command_squishy_speed)
end

--[[
---@param obj Object
local function bhv_custom_mips_loop(obj)
    local m = nearest_interacting_mario_state_to_object(obj)
    local dist = dist_between_objects(obj, m.marioObj)
    local radius = 150

    if dist < radius and m.action == ACT_SQUISHY_SLIDE then
        obj.oMoveAngleYaw = m.faceAngle.y
        obj.oForwardVel = 90
        obj.oVelY = 70
        obj.oAction = MIPS_ACT_FALL_DOWN
        obj.oMipsStarStatus = MIPS_STAR_STATUS_SHOULD_SPAWN_STAR
    end
    obj.oGravity = 5
    if obj.oPosY == obj.oFloorHeight and obj.oVelY < -5 then
        obj.oVelY = math.abs(obj.oVelY) - 5
    end
end

-- hook the behavior
id_bhvCustomMips = hook_behavior(id_bhvMips, OBJ_LIST_PUSHABLE, false, nil, bhv_custom_mips_loop)
]]