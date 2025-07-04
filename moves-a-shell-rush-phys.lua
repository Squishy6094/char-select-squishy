if not _G.charSelectExists then return end

------------------------
-- Shell Rush Physics --
----- By djoslin0 ------
------------------------

--- Reimplement old vec3f --
--- @param dest Vec3f
--- @param src Vec3f
--- @return Vec3f
local function vec3f_copy(dest, src)
    dest.x = src.x
    dest.y = src.y
    dest.z = src.z
    return dest
end

--- @param dest Vec3f
--- @param x number
--- @param y number
--- @param z number
--- @return Vec3f
local function vec3f_set(dest, x, y, z)
    dest.x = x
    dest.y = y
    dest.z = z
    return dest
end

--- @param dest Vec3f
--- @param a Vec3f
--- @return Vec3f
local function vec3f_add(dest, a)
    dest.x = dest.x + a.x
    dest.y = dest.y + a.y
    dest.z = dest.z + a.z
    return dest
end

--- @param dest Vec3f
--- @param a Vec3f
--- @param b Vec3f
--- @return Vec3f
local function vec3f_sum(dest, a, b)
    dest.x = a.x + b.x
    dest.y = a.y + b.y
    dest.z = a.z + b.z
    return dest
end

--- @param dest Vec3f
--- @param a number
--- @return Vec3f
local function vec3f_mul(dest, a)
    dest.x = dest.x * a
    dest.y = dest.y * a
    dest.z = dest.z * a
    return dest
end

--- @param dest Vec3f
--- @return Vec3f
local function vec3f_normalize(dest)
    local divisor = math.sqrt(dest.x * dest.x + dest.y * dest.y + dest.z * dest.z)
    if divisor == 0 then
        return dest
    end

    local invsqrt = 1.0 / divisor
    dest.x = dest.x * invsqrt
    dest.y = dest.y * invsqrt
    dest.z = dest.z * invsqrt

    return dest
end

--- @param a Vec3f
--- @return number
local function vec3f_length(a)
    return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end

--- @param a Vec3f
--- @param b Vec3f
--- @return number
local function vec3f_dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

--- @param vec Vec3f
--- @param onto Vec3f
--- @return Vec3f
local function vec3f_project(vec, onto)
  local numerator = vec3f_dot(vec, onto)
  local denominator = vec3f_dot(onto, onto)
  local out = {}
  vec3f_copy(out, onto)
  vec3f_mul(out, numerator / denominator)
  return out
end

--- @param v1 Vec3f
--- @param v2 Vec3f
--- @return number
local function vec3f_dist(v1, v2)
    dx = v1.x - v2.x
    dy = v1.y - v2.y
    dz = v1.z - v2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Other Functions

local function vec3f_non_nan(v)
    if v.x ~= v.x then v.x = 0 end
    if v.y ~= v.y then v.y = 0 end
    if v.z ~= v.z then v.z = 0 end
end

local function vec3f_angle_between(a, b)
    return math.acos(vec3f_dot(a, b) / (vec3f_length(a) * vec3f_length(b)))
end

local shellSpeed = 0.8

gExtraMarioState = { }

for i = 0, (MAX_PLAYERS - 1) do
    gExtraMarioState[i] = { }
    gExtraMarioState[i].lastY = 0
end

function race_get_slope_physics(m)
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

function race_apply_slope_accel(m)
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

function update_race_shell_speed(m)
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

ACT_SHELL_RUSH_RIDING_SHELL_GROUND = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL)
ACT_SHELL_RUSH_RIDING_SHELL_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL | ACT_FLAG_CONTROL_JUMP_HEIGHT)
ACT_SHELL_RUSH_RIDING_SHELL_FALL = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_RIDING_SHELL)

function act_race_shell_ground(m)
    if m.actionTimer < 5 then m.actionTimer = m.actionTimer + 1 end

    local startYaw = m.faceAngle.y

    -- enforce min velocities
    if m.forwardVel == 0 then m.forwardVel = 1 end
    if vec3f_length(m.vel) == 0 then m.vel.x = 1 end

    -- jump
    if (m.input & INPUT_A_PRESSED) ~= 0 then
        m.vel.x = m.vel.x * 0.9
        m.vel.z = m.vel.z * 0.9
        m.vel.y = 35 + math.sqrt(m.vel.x^2 + m.vel.z^2)*0.5
        return set_mario_action(m, ACT_SHELL_RUSH_RIDING_SHELL_JUMP, 0)
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
        m.vel.y = (m.pos.y - gExtraMarioState[m.playerIndex].lastY)
        return set_mario_action(m, ACT_SHELL_RUSH_RIDING_SHELL_FALL, 0)

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
    gExtraMarioState[m.playerIndex].lastY = m.pos.y
    return 0
end

function act_race_shell_air(m)
    if m.actionTimer < 5 then m.actionTimer = m.actionTimer + 1 end

    play_mario_sound(m, SOUND_ACTION_TERRAIN_JUMP, 0)
    set_mario_animation(m, MARIO_ANIM_JUMP_RIDING_SHELL)

    if m.vel.y > 65 then m.vel.y = 65 end

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
        set_mario_action(m, ACT_SHELL_RUSH_RIDING_SHELL_GROUND, 1)
    elseif step == AIR_STEP_HIT_WALL then
        mario_set_forward_vel(m, 0.0)
    elseif step == AIR_STEP_HIT_LAVA_WALL then
        lava_boost_on_wall(m)
    end

    m.marioObj.header.gfx.pos.y = m.marioObj.header.gfx.pos.y + 42.0
    gExtraMarioState[m.playerIndex].lastY = m.pos.y
    return 0
end

hook_mario_action(ACT_SHELL_RUSH_RIDING_SHELL_GROUND, { every_frame = act_race_shell_ground }, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SHELL_RUSH_RIDING_SHELL_JUMP, { every_frame = act_race_shell_air }, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_SHELL_RUSH_RIDING_SHELL_FALL, { every_frame = act_race_shell_air }, INT_FAST_ATTACK_OR_SHELL)