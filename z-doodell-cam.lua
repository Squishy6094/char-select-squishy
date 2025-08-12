if not _G.charSelectExists then return end

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

local function clamp(num, min, max)
    return math.min(math.max(num, min), max)
end

local OPTION_SQUISHYCAM = _G.charSelect.add_option("Doodell Cam", 1, 2, {"Off", "Squishy Only", "On"}, {"Toggles the unique camera", "built for Squishy's Moveset", (_G.OmmEnabled and "(Inactive with OMM Camera)" or "")}, true)
local OPTION_SQUISHYTIMER = _G.charSelect.add_option("Doodell Timer", 0, 2, {"Off", "Per-Level", "Per-Lobby"}, {"Toggles Doodell's Personal Timer"}, true)

local cutsceneActExclude = {
    [ACT_WARP_DOOR_SPAWN] = true,
    [ACT_PULLING_DOOR] = true,
    [ACT_PUSHING_DOOR] = true,
    [ACT_UNLOCKING_KEY_DOOR] = true,
    [ACT_UNLOCKING_STAR_DOOR] = true,
    [ACT_ENTERING_STAR_DOOR] = true,
    
    [ACT_EMERGE_FROM_PIPE] = true,
    --[ACT_DISAPPEARED] = true,

    [ACT_PICKING_UP_BOWSER] = true,
    [ACT_HOLDING_BOWSER] = true,
    [ACT_RELEASING_BOWSER] = true,
    
    [ACT_RELEASING_BOWSER] = true,
}

local sOverrideCameraModes = {
    [CAMERA_MODE_BEHIND_MARIO]      = true,
    [CAMERA_MODE_WATER_SURFACE]     = true,
    [CAMERA_MODE_RADIAL]            = true,
    [CAMERA_MODE_OUTWARD_RADIAL]    = true,
    [CAMERA_MODE_CLOSE]             = true,
    [CAMERA_MODE_SLIDE_HOOT]        = true,
    [CAMERA_MODE_PARALLEL_TRACKING] = true,
    [CAMERA_MODE_FIXED]             = true,
    [CAMERA_MODE_FREE_ROAM]         = true,
    [CAMERA_MODE_SPIRAL_STAIRS]     = true,
    [CAMERA_MODE_ROM_HACK]          = true,
    [CAMERA_MODE_8_DIRECTIONS]      = true,
    [CAMERA_MODE_BOSS_FIGHT]        = true,
}

local function button_to_analog(m, negInput, posInput)
    local num = 0
    num = num - (m.controller.buttonDown & negInput ~= 0 and 127 or 0)
    num = num + (m.controller.buttonDown & posInput ~= 0 and 127 or 0)
    return num
end

local function omm_camera_enabled()
    if not _G.OmmEnabled then return false end
    return _G.OmmApi.omm_get_setting(gMarioStates[0], OMM_SETTING_CAMERA) == OMM_SETTING_CAMERA_ON
end

local function doodell_cam_enabled()
    local squishyCamToggle = _G.charSelect.get_options_status(OPTION_SQUISHYCAM)
    local isSquishy = _G.charSelect.character_get_current_number() == CT_SQUISHY
    return (squishyCamToggle == 2 or (squishyCamToggle == 1 and isSquishy))
end

function doodell_cam_active()
    local m = gMarioStates[0]
    return doodell_cam_enabled() and
    not camera_is_frozen() and
    not omm_camera_enabled() and
    m.area.camera ~= nil and
    m.statusForCamera.cameraEvent ~= CAM_EVENT_DOOR and
    m.action ~= ACT_STAR_DANCE_EXIT
end

local nonMomentumActs = {
    [ACT_SQUISHY_WALL_SLIDE] = true,
}

local eepyActs = {
    [ACT_SLEEPING] = true,
}

local camAngleRaw = 0
local camAngle = 0
local camScale = 3
local camPitch = 0
local camPan = 0
local camTweenSpeed = 0.3
local camForwardDist = 3
local camPanSpeed = 25
local rawFocusPos = {x = 0, y = 0, z = 0}
local rawCamPos = {x = 0, y = 0, z = 0}
local focusPos = {x = 0, y = 0, z = 0}
local camPos = {x = 0, y = 0, z = 0}
local camFov = 50
local camSwitchHeld = 0

local doodellState = 0
local doodellTimer = 1
local doodellBlink = false
local eepyTimer = 0
local eepyStart = 390
local eepyCamOffset = 0
local prevPos = {x = 0, y = 0, z = 0}

local camSpawnAngles = {
    [LEVEL_BITDW] = 0x4000,
    [LEVEL_BITFS] = 0x4000,
    [LEVEL_BITS] = 0x4000,
    [LEVEL_WF] = 0x4000,
    [LEVEL_TTM] = 0x6000,
    [LEVEL_CCM] = -0x6000,
    [LEVEL_WDW] = 0x4000,
    [LEVEL_LLL] = 0x4000,
    [LEVEL_SSL] = 0x4000,
    [LEVEL_RR] = 0x4000,
}

local function doodell_cam_snap(levelInit)
    if levelInit ~= false then levelInit = true end
    local m = gMarioStates[0]
    local l = gLakituState
    local levelNum = gNetworkPlayers[0].currLevelNum
    local c = m.area.camera
    if levelInit then
        camAngleRaw = round(gMarioStates[0].faceAngle.y/0x2000)*0x2000 - 0x8000 + (camSpawnAngles[levelNum] ~= nil and camSpawnAngles[levelNum] or 0)
        camAngle = camAngleRaw
        camScale = 3
        camPitch = 0
    end
    rawFocusPos = {
        x = m.pos.x,
        y = m.pos.y + 150,
        z = m.pos.z,
    }
    rawCamPos = {
        x = m.pos.x + sins(camAngleRaw) * 500 * camScale,
        y = m.pos.y - 150 + 350 * camScale - eepyCamOffset,
        z = m.pos.z + coss(camAngleRaw) * 500 * camScale,
    }
    vec3f_copy(camPos, rawCamPos)
    vec3f_copy(focusPos, rawFocusPos)
    vec3f_copy(c.pos, camPos)
    vec3f_copy(l.pos, camPos)
    vec3f_copy(l.goalPos, camPos)

    vec3f_copy(c.focus, focusPos)
    vec3f_copy(l.focus, focusPos)
    vec3f_copy(l.goalFocus, focusPos)

    vec3f_copy(prevPos, m.pos)

    camera_set_use_course_specific_settings(0)
end

local timerPerLevel = 0
local timerPerLobby = 0
local timerCheckpoint = 0
local timerCheckpointDisplay = 0

local function update_speedrun_timers()
    timerPerLevel = timerPerLevel + 1
    timerPerLobby = timerPerLobby + 1
    if timerCheckpoint ~= 0 then
        timerCheckpointDisplay = timerCheckpointDisplay + 1
        if timerCheckpointDisplay > 70 then
            timerCheckpointDisplay = 0
            timerCheckpoint = 0
        end
    end
end

local function speedrun_timer_active()
    local squishyTimerToggle = _G.charSelect.get_options_status(OPTION_SQUISHYTIMER)
    if squishyTimerToggle == 0 then return false end
    return true
end

local function speedrun_timer_get()
    if not speedrun_timer_active then return nil end
    local squishyTimerToggle = _G.charSelect.get_options_status(OPTION_SQUISHYTIMER)
    if timerCheckpoint ~= 0 then
        if math.floor(timerCheckpointDisplay/5)%2 == 1 then
            return nil
        else
            return timerCheckpoint
        end
    end
    if squishyTimerToggle == 1 then
        return timerPerLevel
    elseif squishyTimerToggle == 2 then
        return timerPerLobby
    end
end

local function speedrun_timer_checkpoint()
    local squishyTimerToggle = _G.charSelect.get_options_status(OPTION_SQUISHYTIMER)
    if squishyTimerToggle == 1 then
        timerCheckpoint = timerPerLevel
    elseif squishyTimerToggle == 2 then
        timerCheckpoint = timerPerLobby
    end
end

local function speedrun_timer_format(frameTime)
    return string.format("%s:%s.%s", string.format("%02d", math.floor(frameTime/30/60)), string.format("%02d", math.floor(frameTime/30)%60), string.format("%02d", math.floor((frameTime*(10/3))%100)))
end

local prevAction = 0
local function speedrun_timer_check_checkpoint(m)
    if m.playerIndex ~= 0 then return end
    if prevAction ~= m.action then
        if m.action == ACT_FALL_AFTER_STAR_GRAB then
            speedrun_timer_checkpoint()
        end
        if m.prevAction ~= ACT_FALL_AFTER_STAR_GRAB then
            if (m.action == ACT_STAR_DANCE_EXIT or m.action == ACT_STAR_DANCE_NO_EXIT or m.action == ACT_STAR_DANCE_WATER) then
                speedrun_timer_checkpoint()
            end
        end

        prevAction = m.action
    end
end

local mousePullX = 0
local mousePullY = 0
local mousePullMax = 500
local function camera_update()
    local m = gMarioStates[0]
    local l = gLakituState
    local c = m.area.camera
    update_speedrun_timers()
    if c == nil then return end

    -- If turned off, restore camera mode
    local mode = l.mode
    if not doodell_cam_active() then
        if mode == CAMERA_MODE_NONE then
            set_camera_mode(c, CAMERA_MODE_OUTWARD_RADIAL, 0)
        end
        return
    end

    -- Disable Lakitu
    if sOverrideCameraModes[mode] ~= nil or m.action == ACT_SHOT_FROM_CANNON then
        l.mode = CAMERA_MODE_NONE
    end

    if c.cutscene == 0 and l.mode == CAMERA_MODE_NONE then
        doodellState = doodellBlink and 1 or 0
        --camera_freeze()
        local controller = m.controller
        local camSwitch = (controller.buttonDown & R_TRIG ~= 0)
        if not (is_game_paused() or eepyTimer > eepyStart) then
            if camSwitch then
                camSwitchHeld = camSwitchHeld + 1
            end
            local analogToggle = camera_config_is_analog_cam_enabled()

            local invertXMultiply = (camera_config_is_x_inverted() or camera_config_is_mouse_look_enabled()) and -1 or 1
            local invertYMultiply = camera_config_is_y_inverted() and -1 or 1

            local camDigitalLeft  = analogToggle and (_G.OmmEnabled and 0 or L_JPAD) or L_CBUTTONS
            local camDigitalRight = analogToggle and (_G.OmmEnabled and 0 or R_JPAD) or R_CBUTTONS
            local camDigitalUp    = analogToggle and (_G.OmmEnabled and 0 or U_JPAD) or U_CBUTTONS
            local camDigitalDown  = analogToggle and (_G.OmmEnabled and 0 or D_JPAD) or D_CBUTTONS

            local camAnalogX = analogToggle and controller.extStickX or (_G.OmmEnabled and 0 or button_to_analog(m, L_JPAD, R_JPAD))
            local camAnalogY = analogToggle and controller.extStickY or (_G.OmmEnabled and 0 or button_to_analog(m, D_JPAD, U_JPAD))
            

            local mouseCamXDigital = 0
            local mouseCamYDigital = 0
            local rawMouseX = djui_hud_get_raw_mouse_x()
            local rawMouseY = djui_hud_get_raw_mouse_y()
            if camera_config_is_mouse_look_enabled() then
                djui_hud_set_mouse_locked(true)
                mousePullX = clamp(clamp_soft(mousePullX + rawMouseX, 0, 0, 10), -mousePullMax*1.1, mousePullMax*1.1)
                mousePullY = clamp(clamp_soft(mousePullY + rawMouseY, 0, 0, 10), -mousePullMax*1.1, mousePullMax*1.1)
                if not analogToggle then
                    if mousePullX > mousePullMax then
                        mouseCamXDigital = 1
                        mousePullX = 0
                    end
                    if mousePullX < -mousePullMax then
                        mouseCamXDigital = -1
                        mousePullX = 0
                    end
                    if mousePullY > mousePullMax then
                        mouseCamYDigital = 1
                        mousePullY = 0
                    end
                    if mousePullY < -mousePullMax then
                        mouseCamYDigital = -1
                        mousePullY = 0
                    end
                else
                    camAnalogX = rawMouseX*camera_config_get_x_sensitivity()*0.03
                    camAnalogY = -rawMouseY*camera_config_get_y_sensitivity()*0.04
                end
            else
                djui_hud_set_mouse_locked(false)
            end

            if not camSwitch then
                if math.abs(camAnalogX) > 10 then
                    camAngleRaw = camAngleRaw + camAnalogX*10*invertXMultiply
                end
                if math.abs(camAnalogY) > 10 then
                    camScale = clamp(camScale - camAnalogY*0.001, 1, 7)
                end

                if controller.buttonPressed & camDigitalLeft ~= 0 or mouseCamXDigital < 0 then
                    camAngleRaw = camAngleRaw - 0x2000*invertXMultiply
                end
                if controller.buttonPressed & camDigitalRight ~= 0 or mouseCamXDigital > 0 then
                    camAngleRaw = camAngleRaw + 0x2000*invertXMultiply
                end
                if controller.buttonPressed & camDigitalDown ~= 0 or mouseCamYDigital > 0 then
                    camScale = camScale + 1
                end
                if controller.buttonPressed & camDigitalUp ~= 0 or mouseCamYDigital < 0 then
                    camScale = camScale - 1
                end
                camScale = clamp(camScale, 1, 7)
                camPitch = 0
                camPan = 0
            else
                if controller.buttonDown & L_CBUTTONS ~= 0 then
                    camPan = camPan - camPanSpeed*camScale
                end
                if controller.buttonDown & R_CBUTTONS ~= 0 then
                    camPan = camPan + camPanSpeed*camScale
                end
                if controller.buttonDown & D_CBUTTONS ~= 0 then
                    camPitch = camPitch - camPanSpeed*camScale
                end
                if controller.buttonDown & U_CBUTTONS ~= 0 then
                    camPitch = camPitch + camPanSpeed*camScale
                end
            end

            if m.controller.buttonReleased & R_TRIG ~= 0 then
                if camSwitchHeld < 5 then
                    if analogToggle then
                        camAngleRaw = m.faceAngle.y + 0x8000
                    else
                        camAngleRaw = round((m.faceAngle.y + 0x8000)/0x2000)*0x2000
                    end
                end
                camSwitchHeld = 0
            end
        end

        local angle = camAngleRaw
        local roll = ((sins(atan2s(m.vel.z, m.vel.x) - camAngleRaw)*m.forwardVel/150)*0x800)
        if not camSwitch then
            if m.action == ACT_FLYING then
                angle = m.faceAngle.y - 0x8000
                if m.controller.buttonDown & L_CBUTTONS ~= 0 then
                    angle = angle - 0x2000
                end
                if m.controller.buttonDown & R_CBUTTONS ~= 0 then
                    angle = angle + 0x2000
                end
                camAngleRaw = round(angle/0x2000)*0x2000

                if m.action & ACT_FLAG_FLYING ~= 0 then
                    roll = m.faceAngle.z*0.1
                end
            end
        end

        local posVelDist = vec3f_dist(prevPos, m.pos)
        if posVelDist > 500 then
            doodell_cam_snap(false)
        end
        local posVel = {
            x = m.pos.x - prevPos.x,
            y = m.pos.y - prevPos.y,
            z = m.pos.z - prevPos.z,
        }

        local camPanX = sins(convert_s16(camAngleRaw + 0x4000))*camPan
        local camPanZ = coss(convert_s16(camAngleRaw + 0x4000))*camPan

        focusPos = approach_vec3f_asymptotic(l.focus, rawFocusPos, camTweenSpeed, camTweenSpeed, camTweenSpeed)
        camPos = approach_vec3f_asymptotic(l.pos, rawCamPos, camTweenSpeed, camTweenSpeed*0.5, camTweenSpeed)
        vec3f_copy(c.pos, camPos)
        vec3f_copy(l.pos, camPos)
        vec3f_copy(l.goalPos, camPos)

        vec3f_copy(c.focus, focusPos)
        vec3f_copy(l.focus, focusPos)
        vec3f_copy(l.goalFocus, focusPos)

        if m.action == ACT_SQUISHY_GROUND_POUND_LAND then return end

        local velPan = not nonMomentumActs[m.action]
        
        rawFocusPos = {
            x = m.pos.x + camPanX + (velPan  and posVel.x*camForwardDist or 0),
            y = m.pos.y + camPitch + 100 + 100*camScale*0.5 + (velPan and clamp(get_mario_y_vel_from_floor(m), -100, 100)*camForwardDist or 0) - eepyCamOffset,
            z = m.pos.z + camPanZ + (velPan and posVel.z*camForwardDist or 0),
        }
        rawCamPos = {
            x = m.pos.x + (velPan and posVel.x*camForwardDist*2 or 0) + sins(angle) * 500 * camScale,
            y = m.pos.y - (velPan and get_mario_y_vel_from_floor(m)*camForwardDist*1.5 or 0) - 150 + 350*((m.action & ACT_FLAG_HANGING == 0) and 1 or -0.5) * camScale - eepyCamOffset,
            z = m.pos.z + (velPan and posVel.z*camForwardDist*2 or 0) + coss(angle) * 500 * camScale,
        }
        
        if camPitch >= 600*((camScale + 1)/3.5) and
            m.floor and m.floor.type == SURFACE_LOOK_UP_WARP and
            save_file_get_total_star_count(get_current_save_file_num() - 1, COURSE_MIN - 1, COURSE_MAX - 1) >= gLevelValues.wingCapLookUpReq and
            not is_game_paused() then

            level_trigger_warp(m, WARP_OP_LOOK_UP)
        end

        -- Doodell is eepy
        if eepyActs[m.action] then
            doodellState = 4
            eepyTimer = eepyTimer + 1
            local camFloor = collision_find_surface_on_ray(rawCamPos.x, rawCamPos.y + eepyCamOffset, rawCamPos.z, 0, -10000, 0).hitPos.y
            if eepyTimer > eepyStart then
                doodellState = 5
                if rawCamPos.y > (camFloor + 150) then
                    eepyCamOffset = eepyCamOffset + (math.sin(eepyTimer*0.1) + 1)*2
                end
            end
        else
            eepyCamOffset = eepyCamOffset * 0.9
            eepyTimer = 0
        end
        
        l.roll = math.floor(lerp(l.roll, roll, 0.1))
        l.keyDanceRoll = l.roll -- Required for applying rotation because sm64 is fuckin stupid
        --set_camera_roll_shake(1000, 0.1, 1)
        camFov = lerp(camFov, 50 + math.abs(m.forwardVel)*0.1, 0.1)
        set_override_fov(camFov)

        if l.roll < -1000 then
            doodellState = 2
        end
        if l.roll > 1000 then
            doodellState = 3
        end
        vec3f_copy(prevPos, m.pos)
    end
    
    camAngle = atan2s(l.pos.z - l.focus.z, l.pos.x - l.focus.x)
    camAngleInput = atan2s(rawCamPos.z - rawFocusPos.z, rawCamPos.x - rawFocusPos.x)
end

local TEX_DOODELL_CAM = get_texture_info("squishy-doodell-cam")
local MATH_DIVIDE_SHAKE = 1/1000

local doodellScale = 0
local function hud_render()
    if hud_is_hidden() then return end
    local m = gMarioStates[0]
    local l = gLakituState
    djui_hud_set_resolution(RESOLUTION_N64)
    local width = djui_hud_get_screen_width()
    local height = 240

    if doodell_cam_active() then
        doodellTimer = (doodellTimer + 1)%20
        local animFrame = math.floor(doodellTimer*0.1)

        if doodellTimer == 0 then
            doodellBlink = math.random(1, 10) == 1
        end

        doodellScale = lerp(doodellScale, (math.abs(camScale-8)/8)*0.2 + 0.4, 0.1)
        local shakeX = math.random(-1, 1)*math.max(math.abs(l.roll)-1000, 0)*MATH_DIVIDE_SHAKE
        local shakeY = math.random(-1, 1)*math.max(math.abs(l.roll)-1000, 0)*MATH_DIVIDE_SHAKE

        local x = width - 38 - 64*doodellScale + shakeX + (mousePullX/mousePullMax * 4)
        local y = height - 38 - 64*doodellScale + eepyCamOffset*0.1*doodellScale + shakeY + (mousePullY/mousePullMax * 4)
        djui_hud_set_color(255, 255, 255, 255)
        _G.charSelect.hud_hide_element(HUD_DISPLAY_FLAG_CAMERA)
        djui_hud_set_rotation(l.roll, 0.5, 0.8)
        djui_hud_render_texture_tile(TEX_DOODELL_CAM, x, y, doodellScale, doodellScale, animFrame*128, doodellState*128, 128, 128)
        djui_hud_set_rotation(0, 0, 0)
    else
        _G.charSelect.hud_show_element(HUD_DISPLAY_FLAG_CAMERA)
    end

    if speedrun_timer_get() ~= nil then
        djui_hud_set_font(FONT_RECOLOR_HUD)
        djui_hud_set_color(107, 95, 255, 255)
        local timerString = speedrun_timer_format(speedrun_timer_get())
        djui_hud_print_text(timerString, width - djui_hud_measure_text(timerString)*0.8 - 8, height - 26, 0.8)
    end
end

---@param m MarioState
local function input_update(m)
    if m.playerIndex ~= 0 then return end
    if doodell_cam_active() and m.action ~= ACT_FLYING and gLakituState.mode == CAMERA_MODE_NONE then
        local intAngle = m.intendedYaw - camAngleInput
        if (intAngle > 0x3000 and intAngle < 0x5000) or (intAngle > -0x3000 and intAngle < -0x5000) then
            camAngle = camAngleRaw
        end
        local analogToggle = camera_config_is_analog_cam_enabled()
        if not analogToggle then
            camAngle = (camAngle/0x1000)*0x1000
        end
        m.area.camera.yaw = camAngle
        m.intendedYaw = atan2s(-m.controller.stickY, m.controller.stickX) + camAngleInput
    end
end

local function on_level_init()
    if not doodell_cam_active() then return end
    speedrun_timer_checkpoint()
    timerPerLevel = 0
    doodell_cam_snap(true)
end

local function set_camera_mode(_, mode, _)
    if mode == CAMERA_MODE_NONE or camera_config_is_free_cam_enabled() or not doodell_cam_enabled() then
        return true
    end
    if sOverrideCameraModes[mode] ~= nil or gMarioStates[0].action == ACT_SHOT_FROM_CANNON then
        gLakituState.mode = CAMERA_MODE_NONE
        return false
    end
end

local function change_camera_angle(angle)
    if angle == CAM_ANGLE_MARIO and not camera_config_is_free_cam_enabled() and doodell_cam_enabled() then
        return false
    end
end

hook_event(HOOK_ON_HUD_RENDER_BEHIND, hud_render)
hook_event(HOOK_MARIO_UPDATE, speedrun_timer_check_checkpoint)
hook_event(HOOK_BEFORE_MARIO_UPDATE, input_update)
hook_event(HOOK_UPDATE, camera_update)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)
hook_event(HOOK_ON_SET_CAMERA_MODE, set_camera_mode)
hook_event(HOOK_ON_CHANGE_CAMERA_ANGLE, change_camera_angle)
