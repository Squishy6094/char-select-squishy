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

local camAngle = 0
local overrideCamAngle = nil
local camScale = 3
local squishyCamActive = true
local prevSquishyCamActive = false
local camTweenSpeed = 0.15
local originalCamRot = 0
local originalCamRotStall = 0
local prevStickX = 0
local function camera_update()
    local m = gMarioStates[0]
    local l = gLakituState
    local squishyCamToggle = _G.charSelect.get_options_status(OPTION_SQUISHYCAM)
    local isSquishy = _G.charSelect.character_get_current_number() == CT_SQUISHY
    if m.area.camera and m.area.camera.cutscene == 0 then
        squishyCamActive = (squishyCamToggle == 2 or (squishyCamToggle == 1 and isSquishy))
    else
        squishyCamActive = false
    end
    if squishyCamActive then
        camera_freeze()
        if m.controller.buttonPressed & L_CBUTTONS ~= 0 then
            camAngle = camAngle - 0x2000
        end
        if m.controller.buttonPressed & R_CBUTTONS ~= 0 then
            camAngle = camAngle + 0x2000
        end
        if m.controller.buttonPressed & D_CBUTTONS ~= 0 then
            camScale = math.min(camScale + 1, 7)
        end
        if m.controller.buttonPressed & U_CBUTTONS ~= 0 then
            camScale = math.max(camScale - 1, 1)
        end

        --l.mode = CAMERA_MODE_NONE

        local focusPos = {
            x = m.pos.x + m.vel.x*7,
            y = m.pos.y + 150 + m.vel.y*3,
            z = m.pos.z + m.vel.z*7,
        }
        local angle = camAngle
        if m.action & ACT_FLAG_SWIMMING_OR_FLYING ~= 0 then
            angle = m.faceAngle.y - 0x8000
            camAngle = round(angle/0x2000)*0x2000
        end
        local camPos = {
            x = m.pos.x - m.vel.x*3 + sins(angle) * 500 * camScale,
            y = m.pos.y - m.vel.y*3 + 200 * camScale,
            z = m.pos.z - m.vel.z*3 + coss(angle) * 500 * camScale,
        }
        vec3f_copy(l.focus, approach_vec3f_asymptotic(l.focus, focusPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed))
        vec3f_copy(l.pos, approach_vec3f_asymptotic(l.pos, camPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed))
        l.roll = (prevStickX*0x100 + l.roll*0.9)*m.forwardVel/150
        prevSquishyCamActive = squishyCamActive
    else
        if prevSquishyCamActive ~= squishyCamActive then
            camera_unfreeze()
            set_camera_mode(m.area.camera, CAMERA_MODE_NONE, 0)
            prevSquishyCamActive = squishyCamActive
        end
    end
end

---@param m MarioState
local function input_update(m)
    if m.playerIndex ~= 0 then return end
    local l = gLakituState
    if squishyCamActive and m.action & ACT_FLAG_SWIMMING_OR_FLYING == 0 then
        local stickAngle = atan2s(m.controller.rawStickY, m.controller.rawStickX)
        m.controller.stickX = sins(convert_s16(stickAngle - camAngle + originalCamRot))*m.controller.stickMag
        m.controller.stickY = coss(convert_s16(stickAngle - camAngle + originalCamRot))*m.controller.stickMag
        prevStickX = sins(stickAngle)
        djui_chat_message_create(tostring(stickAngle + originalCamRot))
    end
    if not squishyCamActive then
        if not _G.charSelect.is_menu_open() and originalCamRotStall > 3 then
            originalCamRot = atan2s(l.focus.z - l.pos.z, l.focus.x - l.pos.x)
        end
        originalCamRotStall = originalCamRotStall + 1
    end
end

local function on_level_init()
    local l = gLakituState
    originalCamRot = atan2s(l.focus.z - l.pos.z, l.focus.x - l.pos.x)
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, input_update)
hook_event(HOOK_UPDATE, camera_update)
--hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
