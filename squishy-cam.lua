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

local OPTION_SQUISHYCAM = _G.charSelect.add_option("Doodell Cam", 1, 2, {"Off", "Squishy Only", "On"}, {"Toggles the unique camera", "built for Squishy's Moveset"}, true)

local nonMomentumActs = {
    [ACT_SQUISHY_WALL_SLIDE] = true,
}
local nonCameraActs = {
    [ACT_READING_AUTOMATIC_DIALOG] = true,
    [ACT_READING_NPC_DIALOG] = true,
    [ACT_WAITING_FOR_DIALOG] = true,
    [ACT_IN_CANNON] = true
}

local eepyActs = {
    [ACT_SLEEPING] = true,
}

local camAngle = 0
local camScale = 3
local squishyCamActive = true
local prevSquishyCamActive = false
local camTweenSpeed = 0.11
local camForwardDist = 10
local focusPos = {x = 0, y = 0, z = 0}
local camPos = {x = 0, y = 0, z = 0}
local camFov = 50

local doodellState = 0
local doodellTimer = 1
local doodellBlink = false
local eepyTimer = 0
local eepyStart = 390
local eepyCamOffset = 0
local function camera_update()
    local m = gMarioStates[0]
    local l = gLakituState
    local squishyCamToggle = _G.charSelect.get_options_status(OPTION_SQUISHYCAM)
    local isSquishy = _G.charSelect.character_get_current_number() == CT_SQUISHY
    if squishyCamActive then
        doodellState = doodellBlink and 1 or 0
        camera_freeze()
        if not (is_game_paused() or eepyTimer > eepyStart) then
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
        end

        --l.mode = CAMERA_MODE_NONE

        local angle = camAngle
        if m.action & ACT_FLAG_SWIMMING_OR_FLYING ~= 0 then
            angle = m.faceAngle.y - 0x8000
            if m.controller.buttonDown & L_CBUTTONS ~= 0 then
                angle = angle - 0x2000
            end
            if m.controller.buttonDown & R_CBUTTONS ~= 0 then
                angle = angle + 0x2000
            end
            camAngle = round(angle/0x2000)*0x2000
        end
        
        focusPos = {
            x = m.pos.x + (not nonMomentumActs[m.action] and m.vel.x*camForwardDist or 0),
            y = m.pos.y + 150 + (not nonMomentumActs[m.action] and get_mario_y_vel_from_floor(m)*camForwardDist*0.8 or 0) - eepyCamOffset,
            z = m.pos.z + (not nonMomentumActs[m.action] and m.vel.z*camForwardDist or 0),
        }
        camPos = {
            x = m.pos.x + (not nonMomentumActs[m.action] and m.vel.x*7 or 0) + sins(angle) * 500 * camScale,
            y = m.pos.y - (not nonMomentumActs[m.action] and get_mario_y_vel_from_floor(m)*5 or 0) - 150 + 350 * camScale - eepyCamOffset,
            z = m.pos.z + (not nonMomentumActs[m.action] and m.vel.z*7 or 0) + coss(angle) * 500 * camScale,
        }

        -- Doodell is eepy
        if eepyActs[m.action] then
            doodellState = 4
            eepyTimer = eepyTimer + 1
            local camFloor = collision_find_surface_on_ray(camPos.x, camPos.y + eepyCamOffset, camPos.z, 0, -10000, 0).hitPos.y
            if eepyTimer > eepyStart then
                doodellState = 5
                if camPos.y > (camFloor + 150) then
                    eepyCamOffset = eepyCamOffset + (math.sin(eepyTimer*0.1) + 1)*2
                end
            end
        else
            eepyCamOffset = eepyCamOffset * 0.9
            eepyTimer = 0
        end
        
        --warp_camera()
        
        vec3f_copy(l.focus, approach_vec3f_asymptotic(l.focus, focusPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed))
        vec3f_copy(l.pos, approach_vec3f_asymptotic(l.pos, camPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed))
        l.roll = lerp(l.roll, ((sins(atan2s(m.vel.z, m.vel.x) - camAngle)*m.forwardVel/150)*0x800), 0.1)
        camFov = lerp(camFov, 50 + m.forwardVel*0.1, 0.1)
        set_override_fov(camFov)
        prevSquishyCamActive = squishyCamActive

        if l.roll < -1000 then
            doodellState = 2
        end
        if l.roll > 1000 then
            doodellState = 3
        end
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

local TEX_DOODELL_CAM = get_texture_info("squishy-doodell-cam")
local MATH_DIVIDE_SHAKE = 1/1000

local doodellScale = 0
local function hud_render()
    local m = gMarioStates[0]
    local l = gLakituState
    if squishyCamActive then
        djui_hud_set_resolution(RESOLUTION_N64)
        local width = djui_hud_get_screen_width()
        local height = 240
        doodellTimer = (doodellTimer + 1)%20
        local animFrame = math.floor(doodellTimer*0.1)

        if doodellTimer == 0 then
            doodellBlink = math.random(1, 10) == 1
        end

        doodellScale = lerp(doodellScale, (math.abs(camScale-8)/8)*0.2 + 0.4, 0.1)
        local shakeX = math.random(-1, 1)*math.max(math.abs(l.roll)-1000, 0)*MATH_DIVIDE_SHAKE
        local shakeY = math.random(-1, 1)*math.max(math.abs(l.roll)-1000, 0)*MATH_DIVIDE_SHAKE

        djui_hud_set_color(255, 255, 255, 255)
        _G.charSelect.hud_hide_element(HUD_DISPLAY_FLAG_CAMERA)
        djui_hud_set_rotation(l.roll, 0.5, 0.8)
        djui_hud_render_texture_tile(TEX_DOODELL_CAM, width - 38 - 64*doodellScale + shakeX, height - 38 - 64*doodellScale + eepyCamOffset*0.1*doodellScale + shakeY, doodellScale, doodellScale, animFrame*128, doodellState*128, 128, 128)
        djui_hud_set_rotation(l.roll, 0, 0)
    else
        _G.charSelect.hud_show_element(HUD_DISPLAY_FLAG_CAMERA)
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
    camAngle = round(gMarioStates[0].faceAngle.y/0x2000)*0x2000 - 0x8000
end

hook_event(HOOK_ON_HUD_RENDER_BEHIND, hud_render)
hook_event(HOOK_BEFORE_MARIO_UPDATE, input_update)
hook_event(HOOK_UPDATE, camera_update)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
