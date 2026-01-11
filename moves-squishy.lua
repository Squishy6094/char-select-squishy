if not _G.charSelectExists then return end

-------------
-- Moveset --
-------------

gSquishyStates = {}

local function squishy_reset_extra_states(index)
    if index == nil then index = 0 end
    gSquishyStates[index] = {
        index = network_global_index_from_local(0),
        actionTick = 0,
        forwardVelStore = 0,
        yVelStore = 0,
        groundPoundFromRollout = true,
        prevForwardVel = 0,
        intendedDYaw = 0,
        intendedMag = 0,
        sidewaysSpeed = 0,
        prevFloorDist = 0,
        forceDefaultWalk = false,
        prevWallAngle = 0,
        groundpoundCancels = 0,
        panicking = false,
        trickAnim = 0,
        trickCount = 0,
        prevFrameAction = 0,
        hasKoopaShell = false,

        poundVel = 0,

        wallkickAngle = 0,

        gfx = {x = 0, y = 0, z = 0},
    }
end
for i = 0, MAX_PLAYERS - 1 do
    squishy_reset_extra_states(i)
end

----------------------------------------
-- Ported n' Modified Mario Functions --
----------------------------------------

local function update_speed_cap(m, peakVel, force)
    local e = gSquishyStates[m.playerIndex]
    if force == nil then force = false end
    if not force then
        if currRomhack == ROMHACK_SOMARI then
            add_debug_display(m, "Somari H: " .. math.floor(m.forwardVel))
            add_debug_display(m, "Somari V: " .. math.floor(m.vel.y))
            return
        end
    end
    if peakVel == nil then peakVel = 30 end
    if e.panicking then
        peakVel = peakVel * 1.5
        add_debug_display(m, "Panicking!!!")
    end
    m.forwardVel = clamp_soft(m.forwardVel, -peakVel, peakVel, 0.1*math.floor(math.abs(m.forwardVel)/peakVel))
    m.slideVelX = clamp_soft(m.slideVelX, -peakVel, peakVel, 0.1*math.floor(math.abs(m.slideVelX)/peakVel))
    m.slideVelZ = clamp_soft(m.slideVelZ, -peakVel, peakVel, 0.1*math.floor(math.abs(m.slideVelZ)/peakVel))
    if m.vel.y > 0 then
        m.vel.y = clamp_soft(m.vel.y, -peakVel*2, peakVel*2, 0.1*math.floor(math.abs(m.vel.y)/peakVel*2))
    end
    add_debug_display(m, "Speed H: " .. math.floor(m.forwardVel) .. "/" .. peakVel .. " (" .. -0.1*math.floor(math.abs(m.forwardVel)/peakVel) .. ")")
    add_debug_display(m, "Speed V: " .. math.floor(m.vel.y) .. "/" .. peakVel*2 .. " (" .. -0.1*math.floor(math.abs(m.vel.y)/peakVel*2) .. ")")
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

    facingDYaw = convert_s16(m.faceAngle.y - m.slideYaw);
    newFacingDYaw = facingDYaw;

    --! -0x4000 not handled - can slide down a slope while facing perpendicular to it
    -- Fixed
    if (newFacingDYaw > 0 and newFacingDYaw <= 0x4000) then
        newFacingDYaw = newFacingDYaw - 0x200
        if ((newFacingDYaw) < 0) then
            newFacingDYaw = 0;
        end
    elseif (newFacingDYaw > -0x4000 and newFacingDYaw < 0) then
        newFacingDYaw = newFacingDYaw + 0x200
        if ((newFacingDYaw) > 0) then
            newFacingDYaw = 0;
        end
    elseif (newFacingDYaw > 0x4000 and newFacingDYaw < 0x8000) then
        newFacingDYaw = newFacingDYaw + 0x200
        if ((newFacingDYaw) > 0x8000) then
            newFacingDYaw = 0x8000;
        end
    elseif (newFacingDYaw > -0x8000 and newFacingDYaw < -0x4000) then
        newFacingDYaw = newFacingDYaw - 0x200
        if ((newFacingDYaw) < -0x8000) then
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
    local squishyTopSpeed = 40
    local squishyAcceleration = 0.05
    
    local targetSpeed;

    if (m.floor ~= nil and m.floor.type == SURFACE_SLOW) then
        squishyTopSpeed = 30
    end
    if (m.quicksandDepth > 10) then
        squishyTopSpeed = squishyTopSpeed * (6.25 / m.quicksandDepth)
    end

    --[[
    if (m.quicksandDepth > 10) then
        targetSpeed = targetSpeed * (6.25 / m.quicksandDepth)
    end
    ]]

    if currRomhack ~= ROMHACK_SOMARI then
        --[[
        if (m.forwardVel <= 0.0) then
            m.forwardVel = m.forwardVel + 1.1;
        elseif (m.forwardVel <= targetSpeed) then
            m.forwardVel = m.forwardVel + 1.1 - m.forwardVel / 43.0;
        elseif (m.floor.normal.y >= 0.95) then
            m.forwardVel = m.forwardVel - 1.0;
        end
        ]]
        m.forwardVel = math.lerp(m.forwardVel, (m.intendedMag/32 * squishyTopSpeed), squishyAcceleration)
    else
        -- Acceleration
        if m.forwardVel <= 32 then
            m.forwardVel = m.forwardVel + 1.5
        else
            m.forwardVel = m.forwardVel + 0.2
        end
        -- Limit the maxand min speed
        if m.forwardVel > 1200 then
            m.forwardVel = 1200
        elseif m.forwardVel < -100 then
            m.forwardVel = -100
        end
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
    --[[
    if m.action & ACT_FLAG_AIR ~= 0 then
        vmax = 24
        hmin = 0x200
        hmax = 0x2000
    end
    ]]
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
ACT_SQUISHY_SLIDE = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_BUTT_OR_STOMACH_SLIDE | ACT_FLAG_DIVING | ACT_FLAG_SHORT_HITBOX)
ACT_SQUISHY_SLIDE_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_AIR | ACT_FLAG_DIVING | ACT_FLAG_SHORT_HITBOX)
ACT_SQUISHY_FORWARD_ROLLOUT = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_SQUISHY_GROUND_POUND = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_GROUND_POUND_LAND = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
ACT_SQUISHY_GROUND_POUND_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR )
ACT_SQUISHY_WALL_SLIDE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_SWIM_IDLE = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING | ACT_FLAG_WATER_OR_TEXT | ACT_FLAG_STATIONARY)
ACT_SQUISHY_SWIM_MOVING = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING | ACT_FLAG_WATER_OR_TEXT | ACT_FLAG_MOVING)
ACT_SQUISHY_SWIM_ATTACK = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING | ACT_FLAG_WATER_OR_TEXT | ACT_FLAG_MOVING | ACT_FLAG_ATTACKING)
ACT_SQUISHY_WALL_KICK_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_SIDE_FLIP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)
ACT_SQUISHY_LEDGE_GRAB = allocate_mario_action(ACT_GROUP_AUTOMATIC | ACT_FLAG_STATIONARY)
ACT_SQUISHY_TRICK = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_AIR)

local function act_squishy_walking(m)
    local e = gSquishyStates[m.playerIndex]
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
            return set_mario_action(m, ACT_JUMP_KICK, 0)
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
            set_mario_particle_flag(m, PARTICLE_DUST);
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
    local e = gSquishyStates[m.playerIndex]

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
        set_mario_action(m, ACT_LONG_JUMP, 0)
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
    local e = gSquishyStates[m.playerIndex]
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
            return set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 0);
        end

    if (update_squishy_sliding(m, 4.0)) then
        return set_mario_action(m, ACT_STOMACH_SLIDE_STOP, 0)
    end

    common_slide_action(m, ACT_STOMACH_SLIDE_STOP, ACT_SQUISHY_DIVE, MARIO_ANIM_SLIDE_DIVE);
    update_speed_cap(m, 3)
    m.actionTimer = m.actionTimer + 1;
end

--- @param m MarioState
local function update_ramp_off_slope(m, airAction)
    local e = gSquishyStates[m.playerIndex]
    local yVelFloor = get_mario_y_vel_from_floor(m)
    if m.actionTimer > 0 and ((e.yVelStore > 0 and yVelFloor <= 0 and e.yVelStore + yVelFloor > 10) or m.pos.y ~= m.floorHeight) then
        m.vel.y = e.yVelStore
        e.yVelStore = yVelFloor
        return set_mario_action(m, airAction, 0)
    else
        e.yVelStore = yVelFloor
    end
    return 0
end

--- @param m MarioState
local function act_squishy_slide(m)
    local e = gSquishyStates[m.playerIndex]
    if m.actionState == 0 then
        m.slideVelX = sins(m.faceAngle.y)*m.forwardVel
        m.slideVelZ = coss(m.faceAngle.y)*m.forwardVel
        m.actionState = 1
    end
    
    local anim = m.actionArg == 0 and CHAR_ANIM_FORWARD_SPINNING or CHAR_ANIM_SLIDE_KICK
    local turnSpeed = 0x80
    if m.actionArg ~= 0 and m.input & INPUT_Z_DOWN ~= 0 then
        update_speed_cap(m, 20, true)
        set_mario_particle_flag(m, PARTICLE_FIRE)
        turnSpeed = 0x100
        e.gfx.y = m.intendedYaw
    else
        update_speed_cap(m, 25)
    end

    -- Ramp physics
    if update_ramp_off_slope(m, ACT_SQUISHY_SLIDE_AIR) ~= 0 then
        return 1
    end
    if update_squishy_sliding(m, 4) then
        set_mario_action(m, ACT_SLIDE_KICK_SLIDE_STOP, 0)
    end
    common_slide_action(m, ACT_SLIDE_KICK_SLIDE_STOP, ACT_SQUISHY_SLIDE, anim)

    -- Start Water skipping
    if mario_is_on_water(m) then
        m.pos.y = m.pos.y + 10
        m.vel.y = 50
        set_mario_action(m, ACT_SQUISHY_SLIDE_AIR, 0)
    end

    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, turnSpeed, turnSpeed)
    if m.actionTimer > 0 then
        if m.input & INPUT_A_PRESSED ~= 0 then
            if m.actionArg > 0 then
                set_mario_action(m, ACT_DOUBLE_JUMP, 0)
            else
                set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 0)
            end
        end
        if omm_moveset_enabled(m) and m.controller.buttonPressed & X_BUTTON ~= 0 then
            set_mario_action(m, ACT_OMM_CAPPY_THROW_GROUND, 0)
        end
    end

    if m.actionArg == 0 and m.actionTimer > 15 then
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 1)
    end

    m.actionTimer = m.actionTimer + 1
end

--- @param m MarioState
local function act_squishy_slide_air(m)
    local e = gSquishyStates[m.playerIndex]
    common_air_action_step(m, ACT_SQUISHY_SLIDE, MARIO_ANIM_SLIDE_KICK, AIR_STEP_NONE)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0xF0, 0xF0)
    if m.actionArg == 0 then
        if m.forwardVel > 30 and mario_is_on_water(m) and (m.flags & MARIO_METAL_CAP == 0) then
            set_mario_action(m, ACT_SQUISHY_SLIDE_AIR, 0)
            m.forwardVel = m.forwardVel - 2
            set_mario_particle_flag(m, PARTICLE_SHALLOW_WATER_SPLASH)
            m.actionTimer = 0
            e.gfx.x = -0xB0*clamp(m.vel.y, -40, 40)
        end
    else
        m.vel.y = -100
        e.gfx.x = 0x2000
    end
    m.peakHeight = m.pos.y
    m.actionTimer = m.actionTimer + 1
    if m.input & INPUT_Z_DOWN ~= 0 then
        m.actionArg = 1
    end
    if m.input & INPUT_A_PRESSED ~= 0 then
        set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 0)
    end
end

---@param m MarioState
local function act_squishy_forward_rollout(m)
    if not m then return 0 end

    -- Fix Camera from acts like Cannon
    if m.playerIndex == 0 then
        if (not camera_config_is_free_cam_enabled()) then
            set_camera_mode(m.area.camera, m.area.camera.defMode, 1);
        else
            m.area.camera.mode = CAMERA_MODE_NEWCAM;
            gLakituState.mode = CAMERA_MODE_NEWCAM;
        end
    end

    if (m.actionState == 0) then
        if m.vel.y < 30 and m.actionArg == 0 then
            m.vel.y = 30.0;
        end
        set_character_animation(m, MARIO_ANIM_FORWARD_SPINNING_FLIP)
        m.actionState = 1;
    end

    play_mario_sound(m, SOUND_ACTION_TERRAIN_JUMP, 0);

    update_air_without_turn(m);

    local switch = common_air_action_step(m, ACT_FREEFALL_LAND_STOP, CHAR_ANIM_FORWARD_SPINNING, AIR_STEP_NONE)
    if switch == AIR_STEP_NONE then
    elseif switch == AIR_STEP_LANDED then
        play_mario_landing_sound(m, SOUND_ACTION_TERRAIN_LANDING);
        return set_mario_action(m, ACT_FREEFALL_LAND_STOP, 0);
    elseif switch == AIR_STEP_HIT_WALL then
        return set_mario_action(m, ACT_SQUISHY_WALL_SLIDE, 0)
    elseif switch == AIR_STEP_HIT_LAVA_WALL then
        lava_boost_on_wall(m);
    end

    return 0;
end

--- @param m MarioState
local function act_squishy_ground_pound(m)
    if not m then return 0 end
    local e = gSquishyStates[m.playerIndex]

    if m.actionState == 0 then
        m.vel.y = math.max(m.vel.y, 30)
        m.actionState = 1
    end

    e.forwardVelStore = m.forwardVel
    e.poundVel = math.sqrt(m.vel.x^2 + m.vel.y^2 + m.vel.z^2)

    e.gfx.y = e.gfx.y + math.abs(m.vel.y)*0x80

    play_sound_if_no_flag(m, SOUND_ACTION_THROW, MARIO_ACTION_SOUND_PLAYED);

    set_character_animation(m, CHAR_ANIM_GROUND_POUND);

    if (m.input & INPUT_A_PRESSED) ~= 0 and m.pos.y - m.floorHeight > 100 then
        e.poundVel = 0
        m.vel.x = m.vel.x + sins(m.intendedYaw)*50
        m.vel.z = m.vel.z + sins(m.intendedYaw)*50
        set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 0)
    end

    local stepResult = perform_air_step(m, 0);
    if (stepResult == AIR_STEP_LANDED) then
        if (m.playerIndex == 0) then set_camera_shake_from_hit(SHAKE_GROUND_POUND); end
        if (should_get_stuck_in_ground(m) ~= 0) then
            queue_rumble_data_mario(m, 5, 80);
            play_character_sound(m, CHAR_SOUND_OOOF2);
            set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE, 0);
            set_mario_action(m, ACT_FEET_STUCK_IN_GROUND, 0);
        else
            play_mario_heavy_landing_sound(m, SOUND_ACTION_TERRAIN_HEAVY_LANDING);
            set_mario_particle_flags(m, (PARTICLE_MIST_CIRCLE | PARTICLE_HORIZONTAL_STAR), 0);
            set_mario_action(m, ACT_SQUISHY_GROUND_POUND_LAND, 0);
        end
    elseif (stepResult == AIR_STEP_HIT_WALL) then
        set_mario_action(m, ACT_SQUISHY_WALL_SLIDE, 0);
    end

    m.actionTimer = m.actionTimer + 1
    return 0;
end

--- @param m MarioState
local function act_squishy_ground_pound_gravity(m)
    m.vel.y = math.max(m.vel.y - 5, -150)
end

--- @param m MarioState
local function act_squishy_ground_pound_land(m)
    if not m then return 0 end
    local e = gSquishyStates[m.playerIndex]

    if m.actionState == 0 then
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
        m.forwardVel = e.poundVel
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 0);
    end

    if (m.input & INPUT_A_PRESSED) ~= 0 then
        m.vel.y = 60
        m.forwardVel = e.forwardVelStore
        return set_mario_action(m, ACT_SQUISHY_GROUND_POUND_JUMP, 0)
    end

    if (m.input & INPUT_B_PRESSED) ~= 0 then
        m.forwardVel = e.poundVel*0.8
        m.faceAngle.y = m.intendedYaw
        e.poundVel = 0
        set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE, 0);
        return set_mario_action(m, ACT_SQUISHY_SLIDE, 0)
    end

    landing_step(m, CHAR_ANIM_START_CROUCHING, ACT_CROUCHING);
    return 0
end

--- @param m MarioState
local function act_squishy_ground_pound_jump(m)
    local e = gSquishyStates[m.playerIndex]
    common_air_action_step(m, ACT_JUMP_LAND, CHAR_ANIM_SINGLE_JUMP, AIR_STEP_CHECK_LEDGE_GRAB)
    update_omm_air_rotation(m)
    squishy_allow_spin_jump(m)
    if m.actionTimer == 1 then
        play_character_sound(m, CHAR_SOUND_YAHOO_WAHA_YIPPEE)
        e.gfx.y = 0x20000
    end
    if e.gfx.y > 1 then
        e.gfx.y = e.gfx.y*0.8
        m.marioObj.header.gfx.angle.y = m.faceAngle.y + e.gfx.y
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
        set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 0)
    end
end

--- @param m MarioState
local function act_squishy_wall_slide(m)
    local e = gSquishyStates[m.playerIndex]
    local step = perform_air_step(m, AIR_STEP_NONE)
    set_mario_animation(m, MARIO_ANIM_START_WALLKICK)
    
    if e.groundpoundCancels >= 3 then
        return set_mario_action(m, ACT_HARD_BACKWARD_AIR_KB, 0)
    end

    if m.actionState == 0 then
        e.forwardVelStore = (math.sqrt(m.vel.z^2 + m.vel.x^2) + math.min(m.vel.y, 0))
        m.vel.y = e.forwardVelStore
        m.forwardVel = e.forwardVelStore
        if m.wall ~= nil then
            e.prevWallAngle = atan2s(m.wall.normal.z, m.wall.normal.x)
        end
        m.actionState = 1
    end

    m.vel.y = m.vel.y + 0.3
    set_mario_particle_flag(m, PARTICLE_DUST)
    if m.wall == nil or step == AIR_STEP_CHECK_LEDGE_GRAB then
        m.faceAngle.y = e.prevWallAngle
        if m.pos.y == m.floorHeight and e.prevFloorDist < 100 then
            m.forwardVel = m.vel.y
            set_mario_action(m, ACT_FREEFALL_LAND, 0)
        else
            if m.vel.y > 0 then
                m.faceAngle.y = convert_s16(m.faceAngle.y + 0x8000)
                m.vel.y = m.vel.y + 10
                m.forwardVel = 10
                return set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 1)
            else
                m.forwardVel = 0
                return set_mario_action(m, ACT_FREEFALL, 0)
            end
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
        m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - e.prevWallAngle), 0, 0x1000, 0x1000)
        play_sound((m.flags & MARIO_METAL_CAP ~= 0) and SOUND_ACTION_METAL_BONK or SOUND_ACTION_BONK,
                m.marioObj.header.gfx.cameraToObject);


        set_mario_action(m, ACT_SQUISHY_WALL_KICK_AIR, 0)
    end

    if m.input & INPUT_Z_PRESSED ~= 0 then
        m.faceAngle.y = e.prevWallAngle

        play_sound((m.flags & MARIO_METAL_CAP ~= 0) and SOUND_ACTION_METAL_BONK or SOUND_ACTION_BONK,
                m.marioObj.header.gfx.cameraToObject);

        m.forwardVel = 20
        set_mario_action(m, ACT_BACKFLIP, 0)
    end

    m.actionTimer = m.actionTimer + 1
end


--- @param m MarioState
local function act_squishy_swim_idle(m)
    local e = gSquishyStates[m.playerIndex]
    perform_water_step(m)
    set_mario_animation(m, MARIO_ANIM_WATER_IDLE)

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
    local e = gSquishyStates[m.playerIndex]
    perform_water_step(m)
    set_mario_animation(m, MARIO_ANIM_FLUTTERKICK)

    if m.actionTimer == 0 then
        m.forwardVel = math.sqrt(m.vel.x^2 + m.vel.y^2 + m.vel.z^2)
        m.faceAngle.x = atan2s(m.forwardVel, m.vel.y)
    end

    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x400, 0x400)

    if m.input & INPUT_NONZERO_ANALOG ~= 0 or m.input & INPUT_A_DOWN ~= 0 or m.input & INPUT_Z_DOWN ~= 0 then
        if m.forwardVel < 25 then
            m.forwardVel = m.forwardVel + 1
        elseif m.forwardVel > 30 then
            m.forwardVel = m.forwardVel - 2
        end
        m.faceAngle.x = clamp_soft(m.faceAngle.x, 0, 0, 0x180)
    else
        m.forwardVel = math.max(m.forwardVel - 3, 0)
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
    local e = gSquishyStates[m.playerIndex]
    perform_water_step(m)
    set_mario_animation(m, MARIO_ANIM_FORWARD_SPINNING)

    if m.actionTimer == 0 then
        m.forwardVel = m.forwardVel + 10
        e.gfx.z = 0x10000
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
        set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 1)
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
        return set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 0)
    end

    play_mario_jump_sound(m);
    common_air_action_step(m, ACT_JUMP_LAND, MARIO_ANIM_SLIDEJUMP, AIR_STEP_CHECK_LEDGE_GRAB);
    m.actionTimer = m.actionTimer + 1
end

local function act_squishy_side_flip(m)
    if m.actionTimer == 0 then
        m.vel.y = math.max(math.abs(m.forwardVel), 60)
        m.forwardVel = 20
        m.faceAngle.y = m.intendedYaw
    end

    if (m.input & INPUT_B_PRESSED ~= 0) then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0);
    end

    if (m.input & INPUT_Z_PRESSED ~= 0) then
        return set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 0)
    end

    play_mario_jump_sound(m);

    if (common_air_action_step(m, ACT_SIDE_FLIP_LAND, MARIO_ANIM_SLIDEFLIP, AIR_STEP_CHECK_LEDGE_GRAB) ~= AIR_STEP_GRABBED_LEDGE) then
        m.marioObj.header.gfx.angle.y = m.marioObj.header.gfx.angle.y + 0x8000;
    end

    if (m.marioObj.header.gfx.animInfo.animFrame == 6) then
        play_sound(SOUND_ACTION_SIDE_FLIP_UNK, m.marioObj.header.gfx.cameraToObject);
        return false;
    end

    m.actionTimer = m.actionTimer + 1
end

local function act_squishy_ledge_grab(m)
    local e = gSquishyStates[m.playerIndex]
    local heightAboveFloor;
    local intendedDYaw = convert_s16(m.intendedYaw - m.faceAngle.y);
    local hasSpaceForMario = (m.ceilHeight - m.floorHeight >= 160.0);

    if m.actionState == 0 then
        e.forwardVelStore = math.max(math.sqrt(m.forwardVel^2 + m.vel.y^2), 30)
        m.actionState = 0
    end

    if (m.input & (INPUT_Z_PRESSED | INPUT_OFF_FLOOR) ~= 0) then
        return let_go_of_ledge(m);
    end

    if ((m.input & INPUT_A_PRESSED ~= 0) and hasSpaceForMario) then
        m.forwardVel = e.forwardVelStore*0.2
        m.vel.y = e.forwardVelStore*0.8
        return set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 0);
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

local trickSpin = 0x10000
local trickAnims = {
    {anim = MARIO_ANIM_DOUBLE_JUMP_RISE,   name = "Spin",            faceAngleY =  trickSpin*2}, -- Failsafe Anim
    {anim = MARIO_ANIM_DOUBLE_JUMP_RISE,   name = "Spin",            faceAngleY =  trickSpin*2},
    {anim = MARIO_ANIM_BREAKDANCE,         name = "Breakdance",      faceAngleY =  trickSpin},
    {anim = MARIO_ANIM_BACKFLIP,           name = "Backflip"},
    {anim = MARIO_ANIM_TWIRL,              name = "Twirl",           faceAngleY =  trickSpin*3},
    {anim = MARIO_ANIM_IDLE_HEAD_CENTER,   name = "nil",             faceAngleY =  trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_SONIC,      name = "Adventure",       faceAngleX = -trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_GLEE_CO,    name = "Glee Co.",        faceAngleY = -trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_BF_STYLE,   name = "Mic",             faceAngleY =  trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_GF_STYLE,   name = "Speaker",         faceAngleY = -trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_PICO_STYLE, name = "Uzi",             faceAngleY =  trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_NENE_STYLE, name = "Knife",           faceAngleY = -trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_HOTLINE,    name = "Hotline",         faceAngleX =  trickSpin*0.5},
    {anim = SQUISHY_ANIM_TRICK_MIKU,       name = "AKAGE",           faceAngleY = -trickSpin*2},
    {anim = SQUISHY_ANIM_TRICK_TETO,       name = "Drill-Hair",      faceAngleY = -trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_PHONE,      name = "Phone",           faceAngleY =  trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_TEMPRR,     name = "TEMPRR",          faceAngleY =  trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_SURGE,      name = "Electric",        faceAngleY = -trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_DOCTOR,     name = "Doctor",          faceAngleY = trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_JER,        name = "Jer",             faceAngleY = -trickSpin*1},
    {anim = SQUISHY_ANIM_TRICK_JESS,       name = "Jess",            faceAngleY = trickSpin*1},
    {model = E_MODEL_SQUISHY_PLUSH,        name = "Marketable",      faceAngleY = trickSpin*1, sound = audio_sample_load("squishy-plushie.ogg")}
}
table.insert(trickAnims, {model = E_MODEL_SQUISHY_BALATRO, name = "Joker", faceAngleY = trickSpin*2, sound = audio_sample_load("balatro-mult-hit.ogg"), mult = 0})
local jokerTaunt = #trickAnims

local trickPrefixes = {
    "",
    "Bi",
    "Tri",
    "Quadri",
    "Quinque",
    "Sexa",
    "Septi",
    "Octo",
    "Novem",
    "Dec",
    "Fucki",
}

local trickList = {}
local function squishy_trick_combo_add(m, name, mult)
    if m.playerIndex ~= 0 then return end
    if mult == nil then mult = 0 end
    local e = gSquishyStates[m.playerIndex]
    local trickListFound = false
    if e.trickCount == 1 then
        trickList = {}
    end
    if #trickList > 0 then
        for i = 1, #trickList do
            if trickList[i].name == name then
                trickList[i].count = trickList[i].count + 1
                trickList[i].mult = trickList[i].mult + mult
                trickListFound = true
            end
        end
    end
    if not trickListFound then
        table.insert(trickList, {name = name, count = 1, mult = mult})
    end
end

local function squishy_trick_combo_combine(combine, name)
    uniqueFound = {}
    if #trickList > 0 then
        for t = 1, #combine do
            for i = 1, #trickList do
                if combine[t] == trickList[i].name then
                    local unique = true
                    for u = 1, #uniqueFound do
                        if uniqueFound[u] == i then
                            unique = false
                        end
                    end
                    if unique then
                        table.insert(uniqueFound, i)
                    end
                end
            end
        end
    end
    if #uniqueFound == #combine then
        for i = 1, #uniqueFound do
            local found = uniqueFound[i]
            if trickList[found] ~= nil then
                trickList[found].count = trickList[found].count - 1
                if trickList[found].count <= 0 then
                    table.remove(trickList, found)
                end
            end
        end
        squishy_trick_combo_add(gMarioStates[0], name, 1)
    end
end

local function squishy_trick_combo_get()
    local trickName = ""
    squishy_trick_combo_combine({"Spin", "Breakdance", "Backflip", "Twirl"}, "SM64")
    squishy_trick_combo_combine({"Mic", "Speaker", "Uzi", "Knife"}, "Funkin'")
    squishy_trick_combo_combine({"AKAGE", "Drill-Hair", "Phone"}, "Triple Baka")
    squishy_trick_combo_combine({"Jer", "Jess"}, "Green Siblings")
    for i = 1, #trickList do
        local trickData = trickList[i]
        local prefix = trickPrefixes[clamp(trickData.count, 1, #trickPrefixes)]
        trickName = trickName .. (prefix ~= "" and prefix .. "-" or "") .. trickData.name .. " "
    end
    return trickName .. "Trick"
end

local function squishy_trick_combo_get_mult()
    local trickMult = 1
    for i = 1, #trickList do
        trickMult = trickMult + trickList[i].mult
    end
    return trickMult
end

local OPTION_TRICKSOUNDS = _G.charSelect.add_option("Squishy Trick Sounds", 2, 2, {"Minimal", "Local Only", "On"}, {"Toggles Squishy's Trick Sounds"}, true)

local trickSounds = {
    [1] = audio_sample_load("trick1.ogg"),
    [2] = audio_sample_load("trick2.ogg"),
    [3] = audio_sample_load("trick3.ogg"),
    [4] = audio_sample_load("trick4.ogg"),
    [5] = audio_sample_load("trick5.ogg"),
}

local SOUND_TRICK_BAD = audio_sample_load("trickResultB.ogg")
local SOUND_TRICK_GOOD = audio_sample_load("trickResultG.ogg")
local SOUND_TRICK_PERFECT = audio_sample_load("trickResultP.ogg")

local function audio_squishy_taunt_sound(m, sound)
    if not network_mario_is_in_area(m.playerIndex) then return end
    local e = gSquishyStates[m.playerIndex]
    soundToggle = _G.charSelect.get_options_status(OPTION_TRICKSOUNDS)
    if soundToggle == 0 then
        return play_sound(SOUND_GENERAL_GRAND_STAR_JUMP, m.marioObj.header.gfx.cameraToObject)
    end
    if soundToggle == 1 and m.playerIndex ~= 0 then return end
    if sound == nil then sound = trickSounds[clamp(e.trickCount, 1, #trickSounds)] end
    audio_sample_play(sound, m.pos, m.playerIndex == 0 and 1 or 0.5)
end

local function audio_squishy_taunt_land(m, failed)
    if not network_mario_is_in_area(m.playerIndex) then return end
    local e = gSquishyStates[m.playerIndex]
    soundToggle = _G.charSelect.get_options_status(OPTION_TRICKSOUNDS)
    if soundToggle == 0 then return end
    if soundToggle == 1 and m.playerIndex ~= 0 then return end
    if failed then
        audio_sample_play(SOUND_TRICK_BAD, m.pos, 1)
    else
        audio_sample_play(e.trickCount < 6 and SOUND_TRICK_GOOD or SOUND_TRICK_PERFECT, m.pos, m.playerIndex == 0 and 1 or 0.5)
    end
end

local function act_squishy_trick(m)
    local e = gSquishyStates[m.playerIndex]
    local index = network_global_index_from_local(m.playerIndex)
    if m.actionTimer == 0 then
        -- Reset Anim Stuffs
        e.gfx.x = 0
        e.gfx.y = 0
        e.gfx.z = 0
        m.faceAngle.x = 0
        m.faceAngle.z = 0
        m.marioObj.header.gfx.animInfo.animID = -1

        e.trickCount = e.trickCount + 1
        if omm_moveset_enabled(m) then
            m.vel.y = math.max(m.vel.y, 0)
        end
        if m.playerIndex == 0 then
            -- +1 Mult for every Taunt in hand
            trickAnims[jokerTaunt].mult = e.trickCount
            m.actionArg = math.random(2, #trickAnims)
        else
            m.actionArg = 1
        end
        local trickData = trickAnims[clamp(m.actionArg, 1, #trickAnims)]
        e.trickAnim = trickData.anim and trickData.anim or MARIO_ANIM_DOUBLE_JUMP_RISE
        e.gfx.y = trickData.faceAngleY and trickData.faceAngleY or 0
        e.gfx.x = trickData.faceAngleX and trickData.faceAngleX or 0
        e.gfx.z = trickData.faceAngleZ and trickData.faceAngleZ or 0
        if trickData.model ~= nil then
            _G.charSelect.character_edit(CT_SQUISHY, nil, nil, nil, nil, trickData.model)
        end
        squishy_trick_combo_add(m, trickData.name, trickData.mult)
        audio_squishy_taunt_sound(m, trickData.sound)
    end
    add_debug_display(m, ((trickAnims[m.actionArg] and trickAnims[m.actionArg].name) and trickAnims[m.actionArg].name or "???") .. " - " .. m.actionArg)
    m.vel.y = m.vel.y + 2.5/e.trickCount

    update_air_without_turn(m);

    local step = perform_air_step(m, AIR_STEP_NONE)
    if step == AIR_STEP_LANDED then
        if m.actionTimer < 10 then
            e.trickCount = 0
            audio_squishy_taunt_land(m, true)
            set_mario_action(m, ACT_FORWARD_GROUND_KB, 0)
        else
            set_mario_action(m, ACT_FREEFALL_LAND, 0)
        end
    elseif step == AIR_STEP_HIT_WALL then
        if m.actionTimer < 10 then
            e.trickCount = 0
            audio_squishy_taunt_land(m, true)
            set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
        end
    end
    if type(e.trickAnim) == "string" then
        smlua_anim_util_set_animation(m.marioObj, e.trickAnim)
    else
        set_mario_animation(m, e.trickAnim)
    end
    update_omm_air_rotation(m)

    e.gfx.x = e.gfx.x*0.85
    e.gfx.y = e.gfx.y*0.85
    e.gfx.z = e.gfx.z*0.85
    
    if m.actionArg ~= 0 then
        m.actionTimer = m.actionTimer + 1
    end
    if m.actionTimer <= 8 then
        set_mario_particle_flags(m, PARTICLE_SPARKLES, 0)
    else
        if m.input & INPUT_A_PRESSED ~= 0 then
            set_mario_action(m, ACT_SQUISHY_TRICK, 0)
        end
        _G.charSelect.character_edit(CT_SQUISHY, nil, nil, nil, nil, E_MODEL_SQUISHY)
    end
    if m.actionTimer > 15 then
        set_mario_action(m, ACT_FREEFALL, 0)
    end
end

hook_mario_action(ACT_SQUISHY_WALKING, { every_frame = act_squishy_walking})
hook_mario_action(ACT_SQUISHY_CROUCH_SLIDE, { every_frame = act_squishy_crouch_slide})
hook_mario_action(ACT_SQUISHY_DIVE, { every_frame = act_squishy_dive}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_DIVE_SLIDE, { every_frame = act_squishy_dive_slide}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_SLIDE, { every_frame = act_squishy_slide}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_SLIDE_AIR, { every_frame = act_squishy_slide_air})
hook_mario_action(ACT_SQUISHY_FORWARD_ROLLOUT, {every_frame = act_squishy_forward_rollout})
hook_mario_action(ACT_SQUISHY_GROUND_POUND, { every_frame = act_squishy_ground_pound, gravity = act_squishy_ground_pound_gravity}, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_GROUND_POUND_JUMP, { every_frame = act_squishy_ground_pound_jump})
hook_mario_action(ACT_SQUISHY_GROUND_POUND_LAND, act_squishy_ground_pound_land, INT_GROUND_POUND)
hook_mario_action(ACT_SQUISHY_WALL_SLIDE, {every_frame = act_squishy_wall_slide})
hook_mario_action(ACT_SQUISHY_SWIM_IDLE, {every_frame = act_squishy_swim_idle})
hook_mario_action(ACT_SQUISHY_SWIM_MOVING, {every_frame = act_squishy_swim_moving})
hook_mario_action(ACT_SQUISHY_SWIM_ATTACK, {every_frame = act_squishy_swim_attack}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SQUISHY_WALL_KICK_AIR, {every_frame = act_squishy_wall_kick_air})
hook_mario_action(ACT_SQUISHY_SIDE_FLIP, {every_frame = act_squishy_side_flip})
hook_mario_action(ACT_SQUISHY_LEDGE_GRAB, {every_frame = act_squishy_ledge_grab})
hook_mario_action(ACT_SQUISHY_TRICK, {every_frame = act_squishy_trick})
if _G.doorBust then
    _G.doorBust.add_door_bust_action(ACT_SQUISHY_SLIDE)
end

local hitActs = {
    [ACT_BACKWARD_AIR_KB] = true,
    [ACT_FORWARD_AIR_KB] = true,
    [ACT_BACKWARD_GROUND_KB] = true,
    [ACT_FORWARD_GROUND_KB] = true,
    [ACT_HARD_FORWARD_GROUND_KB] = true,
    [ACT_HARD_BACKWARD_GROUND_KB] = true,
    [ACT_SOFT_FORWARD_GROUND_KB] = true,
    [ACT_SOFT_BACKWARD_GROUND_KB] = true,
    [ACT_DEATH_EXIT] = true,
    [ACT_DEATH_EXIT_LAND] = true,
    [ACT_UNUSED_DEATH_EXIT] = true,
    [ACT_FALLING_DEATH_EXIT] = true,
    [ACT_SPECIAL_DEATH_EXIT] = true,
}

local trickBlacklist = {
    [ACT_SQUISHY_TRICK] = true,
    [ACT_SQUISHY_GROUND_POUND] = true,
    [ACT_FLYING] = true,
    [ACT_FALL_AFTER_STAR_GRAB] = true,
    [ACT_LONG_JUMP] = true,
}

local function squishy_update(m)
    local e = gSquishyStates[m.playerIndex]

    -- Global Action Timer 
    e.actionTick = e.actionTick + 1
    add_debug_display(m, "Action Tick: " .. (e.actionTick))

    e.panicking = false
    if m.action & ACT_FLAG_AIR == 0 then
        e.groundpoundCancels = 0
        if e.trickCount > 0 then
            m.forwardVel = m.forwardVel + math.min(e.trickCount*2 * squishy_trick_combo_get_mult(), 100)
            audio_squishy_taunt_land(m)
            e.trickCount = 0
        end
    elseif e.trickCount > 0 and hitActs[m.action] then
        audio_sample_play(SOUND_TRICK_BAD, m.pos, 1)
        e.trickCount = 0
    elseif e.actionTick > 3 and m.input & INPUT_A_PRESSED ~= 0 and not trickBlacklist[m.action] and not hitActs[m.action] then
        set_mario_action(m, ACT_SQUISHY_TRICK, 0)
    end

    -- Revert Trick Model Changes
    if m.action ~= ACT_SQUISHY_TRICK and _G.charSelect.character_get_current_table(CT_SQUISHY).model ~= E_MODEL_SQUISHY then
        _G.charSelect.character_edit(CT_SQUISHY, nil, nil, nil, nil, E_MODEL_SQUISHY)
    end
    add_debug_display(m, "Tricks: " .. (e.trickCount))


    m.vel.y = m.vel.y - math.max(e.groundpoundCancels - 1, 0)*0.6

    if (m.action == ACT_LONG_JUMP or m.action == ACT_SQUISHY_DIVE) and m.input & INPUT_Z_PRESSED ~= 0 then
        set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 0)
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
    if m.action == ACT_SPAWN_SPIN_AIRBORNE or m.action == ACT_SPAWN_NO_SPIN_AIRBORNE then
        m.pos.y = math.min(math.max(m.pos.y - m.floorHeight, 1000) + m.floorHeight, m.ceilHeight - 150) -- Force spawn height
        set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 1)
    end

    if m.health <= 0x300 then
        e.panicking = true
    end

    if m.marioObj.header.gfx.animInfo.animID == CHAR_ANIM_RUNNING then
        if m.forwardVel >= 50 then
            smlua_anim_util_set_animation(m.marioObj, SQUISHY_ANIM_MACH_RUNNING)
            if not e.hasKoopaShell then
                m.marioBodyState.handState = MARIO_HAND_OPEN
            end
        elseif smlua_anim_util_get_current_animation_name(m.marioObj) == SQUISHY_ANIM_MACH_RUNNING then
            m.marioObj.header.gfx.animInfo.animID = -1
        end
    end

    if hitActs[m.action] then
        e.hasKoopaShell = false
    end

    if e.gfx.x ~= 0 then m.marioObj.header.gfx.angle.x = e.gfx.x end
    if e.gfx.y ~= 0 then m.marioObj.header.gfx.angle.y = m.faceAngle.y + e.gfx.y end
    if e.gfx.z ~= 0 then m.marioObj.header.gfx.angle.z = e.gfx.z end
end

---@param m MarioState
local function squishy_before_action(m, nextAct)
    local e = gSquishyStates[m.playerIndex]

    if nextAct == ACT_WALKING and not e.forceDefaultWalk then
        return set_mario_action(m, ACT_SQUISHY_WALKING, 0)
    else
        e.forceDefaultWalk = false
    end
    if nextAct == ACT_GROUND_POUND then
        return set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 0)
    end
    if nextAct == ACT_DIVE then
        return set_mario_action(m, ACT_SQUISHY_DIVE, 0)
    end
    if nextAct == ACT_FORWARD_ROLLOUT then
        return set_mario_action(m, ACT_SQUISHY_FORWARD_ROLLOUT, 0)
    end
    if m.wall ~= nil and nextAct == ACT_AIR_HIT_WALL or nextAct == ACT_OMM_WALL_SLIDE then
        return set_mario_action(m, ACT_SQUISHY_WALL_SLIDE, 0)
    end
    if (nextAct == ACT_BURNING_FALL or nextAct == ACT_BURNING_GROUND or nextAct == ACT_BURNING_JUMP) then
        return set_mario_action(m, ACT_LAVA_BOOST, 0)
    end
    if omm_moveset_enabled(m) then
        if nextAct == ACT_OMM_SPIN_POUND then
            return set_mario_action(m, ACT_SQUISHY_GROUND_POUND, 0)
        end
        if nextAct == ACT_OMM_ROLL then
            return set_mario_action(m, ACT_SQUISHY_SLIDE, 2)
        end
        if nextAct == ACT_OMM_MIDAIR_SPIN then
            return set_mario_action(m, ACT_SQUISHY_TRICK, 2)
        end
    end
    if nextAct == ACT_CROUCH_SLIDE then
        return set_mario_action(m, ACT_SQUISHY_CROUCH_SLIDE, 0)
    end
    if nextAct == ACT_BUTT_SLIDE_AIR then
        return set_mario_action(m, ACT_SQUISHY_SLIDE_AIR, 0)
    end
    if nextAct == ACT_RIDING_SHELL_GROUND then
        e.hasKoopaShell = true
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

    -- Update Anims
    if nextAct ~= m.action then
        e.gfx.x = 0
        e.gfx.y = 0
        e.gfx.z = 0

        m.actionTimer = 0
        e.actionTick = 0
    end
end

local strainingActs = {
    [ACT_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_SQUISHY_FORWARD_ROLLOUT] = true,
    [ACT_SQUISHY_DIVE] = true,
    [ACT_SQUISHY_GROUND_POUND_JUMP] = true,
    [ACT_LONG_JUMP] = true,
}

local canWallkick = {
    [ACT_JUMP] = ACT_JUMP,
    [ACT_HOLD_JUMP] = ACT_HOLD_JUMP,
    [ACT_DOUBLE_JUMP] = ACT_DOUBLE_JUMP,
    [ACT_TRIPLE_JUMP] = ACT_TRIPLE_JUMP,
    [ACT_SIDE_FLIP] = ACT_SIDE_FLIP,
    [ACT_BACKFLIP] = ACT_BACKFLIP,
    [ACT_LONG_JUMP] = ACT_LONG_JUMP,
    [ACT_SQUISHY_WALL_KICK_AIR] = ACT_SQUISHY_WALL_KICK_AIR,
    [ACT_TOP_OF_POLE_JUMP] = ACT_TOP_OF_POLE_JUMP,
    [ACT_FREEFALL] = ACT_FREEFALL,
    
    [ACT_SQUISHY_DIVE] = ACT_SQUISHY_DIVE,
    [ACT_SQUISHY_GROUND_POUND] = ACT_SQUISHY_GROUND_POUND,
    [ACT_SQUISHY_GROUND_POUND_JUMP] = ACT_SQUISHY_GROUND_POUND_JUMP,
    [ACT_SQUISHY_FORWARD_ROLLOUT] = ACT_SQUISHY_FORWARD_ROLLOUT,
}

local wallAngleLimit = 70
local function squishy_before_phys_step(m, step)
    local e = gSquishyStates[m.playerIndex]
    
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
                m.faceAngle.y = convert_s16(m.faceAngle.y + 0x8000)
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

local rainbowColor = { r = 255, g = 0, b = 0 }
local rainbowState = 0
local speedGoal = 100 
local function djui_hud_set_trick_color(a, speed)
    if speed == nil then speed = 1 end
    speed = clamp(speed, 0, speedGoal)
    if rainbowState == 0 then
        rainbowColor.r = rainbowColor.r + speed
        if rainbowColor.r >= 255 then rainbowState = 1 end
    elseif rainbowState == 1 then
        rainbowColor.b = rainbowColor.b - speed
        if rainbowColor.b <= 0 then rainbowState = 2 end
    elseif rainbowState == 2 then
        rainbowColor.g = rainbowColor.g + speed
        if rainbowColor.g >= 255 then rainbowState = 3 end
    elseif rainbowState == 3 then
        rainbowColor.r = rainbowColor.r - speed
        if rainbowColor.r <= 0 then rainbowState = 4 end
    elseif rainbowState == 4 then
        rainbowColor.b = rainbowColor.b + speed
        if rainbowColor.b >= 255 then rainbowState = 5 end
    elseif rainbowState == 5 then
        rainbowColor.g = rainbowColor.g - speed
        if rainbowColor.g <= 0 then rainbowState = 0 end
    end
    rainbowColor.r = clamp(rainbowColor.r, 0, 255)
    rainbowColor.g = clamp(rainbowColor.g, 0, 255)
    rainbowColor.b = clamp(rainbowColor.b, 0, 255)
    local colorFade = speed/(speedGoal*1.1)
    return djui_hud_set_color(
    clamp((colorFade) * 255 + (1 - colorFade) * rainbowColor.r, 0, 255),
    clamp((colorFade) * 255 + (1 - colorFade) * rainbowColor.g, 0, 255),
    clamp((colorFade) * 255 + (1 - colorFade) * rainbowColor.b, 0, 255),
    a)
end

local OPTION_TRICKDISPLAY = _G.charSelect.add_option("Squishy Trick Display", 1, 1, nil, {"Toggles Squishy's Trick Display"}, true)

local trickTextY = 0
local trickTextVel = 0
local prevTrickCount = 0
local trickName = ""
local trickScore = 0
local trickOpacity = 0
local function hud_render_behind()
    djui_hud_set_resolution(RESOLUTION_N64)
    local width = djui_hud_get_screen_width()
    local height = djui_hud_get_screen_height()
    local m = gMarioStates[0]
    local e = gSquishyStates[0]

    if _G.charSelect.get_options_status(OPTION_TRICKDISPLAY) == 1 then
        if prevTrickCount < e.trickCount then
            trickTextVel = 10
            prevTrickCount = e.trickCount
        end
        trickTextY = trickTextY + trickTextVel*0.2
        trickTextVel = trickTextVel - 2
        if trickTextY < 0 then
            trickTextY = 0
            trickTextVel = 0
        end
        if e.trickCount == 0 then
            if prevTrickCount ~= e.trickCount then
                if hitActs[m.action] then
                    trickName = "Failed " .. trickName
                    trickScore = trickScore*0.5
                    rainbowColor = { r = 255, g = 0, b = 0 }
                    rainbowState = 0
                else
                    trickScore = trickScore * math.max(squishy_trick_combo_get_mult(), 1)
                end
                prevTrickCount = e.trickCount
            end
            trickScore = math.floor(math.max(trickScore*0.95, 0))
        else
            trickName = squishy_trick_combo_get()
            trickScore = e.trickCount*200
        end

        if trickScore > 0 then
            trickOpacity = trickOpacity + 20
        else
            trickOpacity = trickOpacity - 3
        end
        trickOpacity = clamp(trickOpacity, 0, 255)

        local trickMult = (e.trickCount > 0 and squishy_trick_combo_get_mult() or 0)
        djui_hud_set_trick_color(trickOpacity, trickScore/100 * math.max(trickMult, 1))
        djui_hud_set_font(FONT_RECOLOR_HUD)
        local trickNameLength = djui_hud_measure_text(trickName)
        local trickTextScale = clamp((width - 80)/trickNameLength, 0.3, 1)
        local x = width*0.5 - trickNameLength*trickTextScale*0.5
        local y = height - 64 - trickTextY
        djui_hud_print_text(trickName, x, y + (1 - trickTextScale)*16, trickTextScale)

        local trickScoreText = "SCORE: " .. trickScore .. (trickMult > 1 and " x " .. trickMult or "")
        djui_hud_print_text(trickScoreText, width*0.5 - djui_hud_measure_text(trickScoreText)*0.5, y + 20, 1)
    end
end

local forceWalkingInteracts = {
    [id_bhvDoor] = true,
    [id_bhvDoorWarp] = true,
    [id_bhvStarDoor] = true,
    [id_bhvBowserKeyUnlockDoor] = true,
    [id_bhvTowerDoor] = true,
    [id_bhvKoopaShell] = true,
}

local function on_interact(m, obj, type)
    local e = gSquishyStates[m.playerIndex]
    local bhvID = get_id_from_behavior(obj.behavior)
    if forceWalkingInteracts[bhvID] and m.action == ACT_SQUISHY_WALKING then
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
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ON_HUD_RENDER_BEHIND, hud_render_behind)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ON_LEVEL_INIT, squishy_reset_extra_states)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ON_INTERACT, on_interact)
    _G.charSelect.character_hook_moveset(CT_SQUISHY, HOOK_ALLOW_INTERACT, allow_interact)
end
hook_event(HOOK_ON_MODS_LOADED, on_character_select_load)