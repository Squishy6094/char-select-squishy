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

local function lerp(a, b, t)
    return a * (1 - t) + b * t
end

local function approach_vec3f_asymptotic(current, target, multX, multY, multZ)
    local output = {x = 0, y = 0, z = 0}
    output.x = current.x + ((target.x - current.x)*multX)
    output.y = current.y + ((target.y - current.y)*multY)
    output.z = current.z + ((target.z - current.z)*multZ)
    return output
end

local function round(num)
    return num < 0.5 and math.floor(num) or math.ceil(num)
end

local OPTION_SQUISHYCAM = _G.charSelect.add_option("Squishy Cam", 1, 2, {"Off", "Squishy", "On"}, {"Toggles the unique camera", "built for Squishy's Moveset"}, true)

local nonMomentumActs = {
    [ACT_SQUISHY_WALL_SLIDE] = true,
}
local nonCameraActs = {
    [ACT_READING_AUTOMATIC_DIALOG] = true,
    [ACT_READING_NPC_DIALOG] = true,
    [ACT_WAITING_FOR_DIALOG] = true,
    [ACT_IN_CANNON] = true
}

local camAngle = 0
local camScale = 3
local squishyCamActive = true
local prevSquishyCamActive = false
local camTweenSpeed = 0.11
local focusPos = {x = 0, y = 0, z = 0}
local camPos = {x = 0, y = 0, z = 0}
local camFov = 50
local function camera_update()
    local m = gMarioStates[0]
    local l = gLakituState
    local squishyCamToggle = _G.charSelect.get_options_status(OPTION_SQUISHYCAM)
    local isSquishy = _G.charSelect.character_get_current_number() == CT_SQUISHY
    if squishyCamActive then
        camera_freeze()
        if m.controller.buttonPressed & L_CBUTTONS ~= 0 then
            camAngle = camAngle - 0x2000
        end
        if m.controller.buttonPressed & R_CBUTTONS ~= 0 then
            camAngle = camAngle + 0x2000
        end
        if m.controller.buttonDown & R_TRIG ~= 0 then
            camAngle = round((m.faceAngle.y - 0x8000)/0x2000)*0x2000
        end
        if m.controller.buttonPressed & D_CBUTTONS ~= 0 then
            camScale = math.min(camScale + 1, 7)
        end
        if m.controller.buttonPressed & U_CBUTTONS ~= 0 then
            camScale = math.max(camScale - 1, 1)
        end

        --l.mode = CAMERA_MODE_NONE
        
        focusPos = {
            x = m.pos.x + (not nonMomentumActs[m.action] and m.vel.x*10 or 0),
            y = m.pos.y + 50 + (not nonMomentumActs[m.action] and m.vel.y*7 or 0),
            z = m.pos.z + (not nonMomentumActs[m.action] and m.vel.z*10 or 0),
        }
        local angle = camAngle
        if m.action & ACT_FLAG_SWIMMING_OR_FLYING ~= 0 then
            angle = m.faceAngle.y - 0x8000
            camAngle = round(angle/0x2000)*0x2000
        end
        camPos = {
            x = m.pos.x + (not nonMomentumActs[m.action] and m.vel.x*7 or 0) + sins(angle) * 500 * camScale,
            y = m.pos.y - (not nonMomentumActs[m.action] and m.vel.y*5 or 0) + 300 * camScale,
            z = m.pos.z + (not nonMomentumActs[m.action] and m.vel.z*7 or 0) + coss(angle) * 500 * camScale,
        }
        vec3f_copy(l.focus, approach_vec3f_asymptotic(l.focus, focusPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed))
        vec3f_copy(l.pos, approach_vec3f_asymptotic(l.pos, camPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed))
        l.roll = lerp(l.roll, ((sins(atan2s(m.vel.z, m.vel.x) - camAngle)*m.forwardVel/150)*0x800), 0.1)
        camFov = lerp(camFov, 50 + m.forwardVel*0.1, 0.1)
        set_override_fov(camFov)
        prevSquishyCamActive = squishyCamActive
    else
        if prevSquishyCamActive ~= squishyCamActive then
            camera_unfreeze()
            vec3f_copy(l.focus, approach_vec3f_asymptotic(l.focus, focusPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed))
            vec3f_copy(l.pos, approach_vec3f_asymptotic(l.pos, camPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed))
            set_camera_mode(m.area.camera, CAMERA_MODE_NONE, 0)
            prevSquishyCamActive = squishyCamActive
        end
    end
    if m.area.camera and m.area.camera.cutscene == 0 and not nonCameraActs[m.action] then
        squishyCamActive = (squishyCamToggle == 2 or (squishyCamToggle == 1 and isSquishy))
    else
        squishyCamActive = false
    end
end

---@param m MarioState
local function input_update(m)
    if m.playerIndex ~= 0 then return end
    if squishyCamActive and m.action & ACT_FLAG_SWIMMING_OR_FLYING == 0 then
        m.area.camera.yaw = camAngle
        m.intendedYaw = atan2s(-m.controller.stickY, m.controller.stickX) + camAngle
    end
end

local function on_level_init()
    local l = gLakituState
    originalCamRot = atan2s(l.focus.z - l.pos.z, l.focus.x - l.pos.x)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, input_update)
hook_event(HOOK_UPDATE, camera_update)
--hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
