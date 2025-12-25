if not _G.charSelectExists then return end

-------------
-- Moveset --
-------------

gShellStates = {}

local function shell_reset_extra_states(index)
    if index == nil then index = 0 end
    gShellStates[index] = {
        index = network_global_index_from_local(0),
        actionTick = 0,
        canAirJump = 0,
        crouchScale = 0,

        gfx = {x = 0, y = 0, z = 0},
        animAccel = 1,
    }
end
for i = 0, MAX_PLAYERS - 1 do
    shell_reset_extra_states(i)
end

ACT_SHELL_AIR_JUMP = allocate_mario_action(ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION | ACT_GROUP_AIRBORNE)
ACT_SHELL_FLUTTER = allocate_mario_action(ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION | ACT_GROUP_AIRBORNE)
ACT_SHELL_CROUCHING = allocate_mario_action(ACT_FLAG_SHORT_HITBOX)
ACT_SHELL_CROUCH_JUMP = allocate_mario_action(ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION | ACT_GROUP_AIRBORNE | ACT_FLAG_CONTROL_JUMP_HEIGHT | ACT_FLAG_SHORT_HITBOX)
ACT_SHELL_BREAKDANCE = allocate_mario_action(ACT_FLAG_SHORT_HITBOX | ACT_FLAG_AIR)

local function act_shell_air_jump(m)    
    if not m then return 0 end
    local e = gShellStates[m.playerIndex]

    -- Fix Camera from acts like Cannon
    if m.playerIndex == 0 then
        if (not camera_config_is_free_cam_enabled()) then
            set_camera_mode(m.area.camera, m.area.camera.defMode, 1);
        else
            m.area.camera.mode = CAMERA_MODE_NEWCAM;
            gLakituState.mode = CAMERA_MODE_NEWCAM;
        end
    end

    local animation = (m.vel.y >= 0.0) and CHAR_ANIM_DOUBLE_JUMP_RISE or CHAR_ANIM_DOUBLE_JUMP_FALL;
    if m.actionState == 0 then
        m.vel.y = 40
        e.gfx.y = 0x10000
        m.actionState = m.actionState + 1
        set_mario_particle_flag(m, PARTICLE_MIST_CIRCLE)
    end

    if (check_kick_or_dive_in_air(m) ~= 0) then
        return 1;
    end

    if (m.input & INPUT_Z_PRESSED ~= 0) then
        return set_mario_action(m, ACT_GROUND_POUND, 0);
    end

    e.gfx.y = math.lerp(e.gfx.y, 0, 0.2)
    play_mario_sound(m, SOUND_ACTION_TERRAIN_JUMP, CHAR_SOUND_HOOHOO);
    common_air_action_step(m, ACT_DOUBLE_JUMP_LAND, animation, AIR_STEP_CHECK_LEDGE_GRAB | AIR_STEP_CHECK_HANG);
    return 0;
end

local function act_shell_air_jump_gravity(m)
    m.vel.y = math.max(m.vel.y - 3, -70)
end

---@param m MarioState
local function act_shell_flutter(m)
    local e = gShellStates[m.playerIndex]
    if (m.vel.y >= 25) or (m.input & INPUT_A_DOWN) == 0 or (m.actionTimer > 45) or (m.ceilHeight - m.pos.y <= 190) then
        e.gfx.x = 0
        if m.flags & MARIO_WING_CAP ~= 0 then
            e.canAirJump = 1
            return set_mario_action(m, ACT_SHELL_AIR_JUMP, 0)
        else
            return set_mario_action(m, ACT_FORWARD_ROLLOUT, 0)
        end
    end

    if (check_kick_or_dive_in_air(m) ~= 0) then
        return 1;
    end

    if (m.input & INPUT_Z_PRESSED ~= 0) then
        return set_mario_action(m, ACT_GROUND_POUND, 0);
    end

    if m.actionState == 0 then
        play_character_sound(m, CHAR_SOUND_TWIRL_BOUNCE) -- Play audio sample
        m.actionState = m.actionState + 1
    end
    
    if m.forwardVel > 0 then
        m.forwardVel = math.lerp(m.forwardVel, 0, 0.05)
    end

    common_air_action_step(m, ACT_JUMP_LAND, CHAR_ANIM_RUNNING_UNUSED, 0)
    m.marioBodyState.eyeState = MARIO_EYES_DEAD
    e.animAccel = 15
    e.gfx.x = m.vel.y * -0xC0
    set_mario_particle_flag(m, PARTICLE_DUST)

    m.actionTimer = m.actionTimer + 1
    return false
end

local function act_shell_flutter_gravity(m)
    m.vel.y = math.lerp(m.vel.y, 40, 0.06)
    add_debug_display(m, "Flutter Vel: " .. math.round(m.vel.y))
end

local function act_shell_crouching(m)
    if m.input & INPUT_A_PRESSED ~= 0 then
        m.vel.y = 40
        return set_mario_action(m, ACT_SHELL_CROUCH_JUMP, 0)
    end

    if m.forwardVel > 0 then
        if m.input & INPUT_B_PRESSED ~= 0 then
            return set_mario_action(m, ACT_SHELL_BREAKDANCE, 0)
        end

        common_slide_action_with_jump(m, ACT_SHELL_CROUCHING, ACT_SHELL_CROUCH_JUMP, ACT_SHELL_CROUCH_JUMP, CHAR_ANIM_CROUCHING)
    else
        if m.input & INPUT_Z_DOWN == 0 then
            return set_mario_action(m, ACT_IDLE, 0)
        end

        set_character_animation(m, CHAR_ANIM_CROUCHING)
        step = perform_ground_step(m)
        if step == GROUND_STEP_LEFT_GROUND then
            return set_mario_action(m, ACT_SHELL_CROUCH_JUMP, 0)
        end
    end

    return false
end

local function act_shell_crouch_jump(m)
    if m.input & INPUT_Z_DOWN == 0 then
        return set_mario_action(m, ACT_IDLE, 0)
    end

    common_air_action_step(m, ACT_CROUCH_SLIDE, CHAR_ANIM_CROUCHING, 0)

    return false
end

local function act_shell_breakdance(m)
    local e = gShellStates[m.playerIndex]
    local spinout = m.forwardVel > 0
    if m.actionArg == 0 then
        local t = (m.actionTimer - 17) / 13
        if m.actionState == 0 then
            m.forwardVel = math.max(m.forwardVel, 50)
            m.actionState = 1
        else
            add_debug_display(m, "Breakdance Vel: " .. math.round(m.forwardVel) .. " (" .. math.round(m.forwardVel*1.5) .. ")")
            if m.forwardVel > 10 and (m.input & INPUT_B_PRESSED ~= 0) then
                m.vel.y = 30
                return set_mario_action(m, ACT_SHELL_BREAKDANCE, 1)
            end
        end
        
        step = common_slide_action_with_jump(m, ACT_SHELL_CROUCHING, ACT_SHELL_AIR_JUMP, ACT_SHELL_CROUCH_JUMP, spinout and CHAR_ANIM_BREAKDANCE or CHAR_ANIM_AIRBORNE_ON_STOMACH)

        -- Breakdance Anim
        vec3f_set(m.marioObj.header.gfx.pos, m.pos.x + -20 * sins(m.faceAngle.y), m.pos.y, m.pos.z + -20 * coss(m.faceAngle.y))
        if m.marioObj.header.gfx.animInfo.animFrame >= 16 then
            set_anim_to_frame(m, 1)
        end

        e.animAccel = (math.abs(m.forwardVel) + 10)*0.04
    else
        if m.actionState == 0 then
            m.forwardVel = m.forwardVel*1.5
            m.actionState = 1
        end

        m.vel.y = m.vel.y + 1

        common_air_action_step(m, ACT_SLIDE_KICK_SLIDE, CHAR_ANIM_SLIDE_KICK, 0)
    end

    m.actionTimer = m.actionTimer + 1
    return false
end

hook_mario_action(ACT_SHELL_AIR_JUMP, {every_frame = act_shell_air_jump, gravity = act_shell_air_jump_gravity}, 0)
hook_mario_action(ACT_SHELL_FLUTTER, {every_frame = act_shell_flutter, gravity = act_shell_flutter_gravity}, 0)
hook_mario_action(ACT_SHELL_CROUCHING, act_shell_crouching, 0)
hook_mario_action(ACT_SHELL_CROUCH_JUMP, act_shell_crouch_jump, 0)
hook_mario_action(ACT_SHELL_BREAKDANCE, act_shell_breakdance, INT_SLIDE_KICK)

local crouchActs = {
    [ACT_CROUCHING] = true,
    [ACT_CROUCH_SLIDE] = true,
    [ACT_START_CROUCHING] = true,
    [ACT_STOP_CROUCHING] = true,

    [ACT_SHELL_CROUCHING] = false,
    [ACT_SHELL_CROUCH_JUMP] = false,
}

---@param m MarioState
local function shell_update(m)
    local e = gShellStates[m.playerIndex]

    e.actionTick = e.actionTick + 1
    add_debug_display(m, "Action Tick: " .. (e.actionTick))

    -- Air Actions
    if m.action & ACT_FLAG_AIR ~= 0 then
        if m.action & ACT_FLAG_INVULNERABLE == 0 and e.actionTick > 1 and m.input & INPUT_A_PRESSED ~= 0 then
            if e.canAirJump == 0 then
                set_mario_action(m, ACT_SHELL_AIR_JUMP, 0)
            elseif e.canAirJump == 1 then
                set_mario_action(m, ACT_SHELL_FLUTTER, 0)
            end
            e.canAirJump = e.canAirJump + 1
        end
    else
        e.canAirJump = 0
    end

    -- Crouch Anim
    if math.round(e.crouchScale*100) ~= 100 then
        local newScale = math.lerp(e.crouchScale, 1, 0.4)
        local objScale = (e.crouchScale - newScale)
        add_debug_display(m, "Crouch Scale: " .. math.floor(objScale * 1000)*0.01)
        obj_set_gfx_scale(m.marioObj, 1 - objScale, 1 + objScale, 1 - objScale)
        e.crouchScale = newScale
    end

    if e.gfx.x ~= 0 then m.marioObj.header.gfx.angle.x = e.gfx.x end
    if e.gfx.y ~= 0 then m.marioObj.header.gfx.angle.y = m.faceAngle.y + e.gfx.y end
    if e.gfx.z ~= 0 then m.marioObj.header.gfx.angle.z = e.gfx.z end
    if e.animAccel ~= 1 then m.marioObj.header.gfx.animInfo.animAccel = 0x10000 * e.animAccel end
end

local function shell_before_action(m, nextAct)
    local e = gShellStates[m.playerIndex]

    if nextAct ~= m.action then
        e.gfx.x = 0
        e.gfx.y = 0
        e.gfx.z = 0
        e.animAccel = 1

        m.marioObj.header.gfx.angle.x = 0
        m.marioObj.header.gfx.angle.y = m.faceAngle.y
        m.marioObj.header.gfx.angle.z = 0
        m.marioObj.header.gfx.animInfo.animAccel = 0x10000

        m.actionTimer = 0
        e.actionTick = 0
    end

    if crouchActs[nextAct] then
        if crouchActs[m.action] == nil then
            e.crouchScale = 2
        end
        return set_mario_action(m, ACT_SHELL_CROUCHING, 0)
    elseif crouchActs[m.action] ~= nil then
        e.crouchScale = 0.4
    end
end


local function on_character_select_load()
    _G.charSelect.character_hook_moveset(CT_SHELL, HOOK_MARIO_UPDATE, shell_update)
    _G.charSelect.character_hook_moveset(CT_SHELL, HOOK_BEFORE_SET_MARIO_ACTION, shell_before_action)
end
hook_event(HOOK_ON_MODS_LOADED, on_character_select_load)