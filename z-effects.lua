if not _G.charSelectExists then return end

E_MODEL_SLIDE_SPARK = smlua_model_util_get_id("squishy_slide_spark_geo")

gPlayerObjects = {}
for i = 0, (MAX_PLAYERS - 1) do
    gPlayerObjects[i] = nil
end

------------

define_custom_obj_fields({
    oPlayerIndex = 'u32',
})

local function bhv_spark_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oOpacity = 0
    obj.hookRender = 1
    obj_scale(obj, 1)
    obj.hitboxRadius = 100
    obj.hitboxHeight = 100
    obj.oIntangibleTimer = 0
    cur_obj_hide()
end

local function bhv_spark_loop(obj)
    local m = gMarioStates[obj.oPlayerIndex]
    --local s = gPlayerSyncTable[obj.oPlayerIndex]
    --local e = gMarioStateExtras[obj.oPlayerIndex]

    -- check if this should be inactive
    --if not active_player(m) then
    --    cur_obj_hide()
    --    return
    -- end

    -- if the player is off screen, hide the obj
    if m.marioBodyState.updateTorsoTime ~= gMarioStates[0].marioBodyState.updateTorsoTime then
        cur_obj_hide()
        return
    end

    -- update pallet
    local np = gNetworkPlayers[obj.oPlayerIndex]
    if np ~= nil then
        obj.globalPlayerIndex = np.globalIndex
    end

    -- check if this should be activated
    if obj_is_hidden(obj) ~= 0 then
        cur_obj_unhide()
        obj_set_model_extended(obj, E_MODEL_SLIDE_SPARK)
        obj_scale(obj, 1)
        obj.oAnimState = 0
        obj.header.gfx.node.flags = obj.header.gfx.node.flags & ~GRAPH_RENDER_BILLBOARD
        obj.oAnimations = nil
    end

    if m.action == ACT_SQUISHY_SLIDE and m.actionTimer > 5 and m.forwardVel > 60 then
        cur_obj_unhide()
        obj.oOpacity = math.min(m.forwardVel/70, 1)*255
    else
        cur_obj_hide()
    end
end

local id_bhvSquishySlideSpark = hook_behavior(nil, OBJ_LIST_DEFAULT, true, bhv_spark_init, bhv_spark_loop, "id_bhvSquishySlideSpark")

local function bhv_held_shell_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oOpacity = 0
    obj.hookRender = 1
    obj_scale(obj, 1)
    obj.hitboxRadius = 100
    obj.hitboxHeight = 100
    obj.oIntangibleTimer = 0
    cur_obj_hide()
end

local function bhv_held_shell_loop(obj)
    local m = gMarioStates[obj.oPlayerIndex]
    local e = gSquishyExtraStates[obj.oPlayerIndex]
    --local s = gPlayerSyncTable[obj.oPlayerIndex]
    --local e = gMarioStateExtras[obj.oPlayerIndex]

    -- check if this should be inactive
    --if not active_player(m) then
    --    cur_obj_hide()
    --    return
    -- end

    -- if the player is off screen, hide the obj
    if m.marioBodyState.updateTorsoTime ~= gMarioStates[0].marioBodyState.updateTorsoTime then
        cur_obj_hide()
        return
    end

    -- update pallet
    local np = gNetworkPlayers[obj.oPlayerIndex]
    if np ~= nil then
        obj.globalPlayerIndex = np.globalIndex
    end

    -- check if this should be activated
    if obj_is_hidden(obj) ~= 0 then
        cur_obj_unhide()
        obj_set_model_extended(obj, E_MODEL_KOOPA_SHELL)
        obj_scale(obj, 1)
        obj.oAnimState = 0
        obj.header.gfx.node.flags = obj.header.gfx.node.flags & ~GRAPH_RENDER_BILLBOARD
        obj.oAnimations = nil
    end

    if e.hasKoopaShell and m.action & ACT_FLAG_RIDING_SHELL == 0 then
        cur_obj_unhide()
        cur_obj_hide()
        --obj.oOpacity = math.min(m.forwardVel/70, 1)*255
    else
        cur_obj_hide()
    end
end

local id_bhvSquishyHeldShell = hook_behavior(nil, OBJ_LIST_DEFAULT, true, bhv_held_shell_init, bhv_held_shell_loop, "id_bhvSquishyHeldShell")

------------

local function on_sync_valid()
    for i = 0, (MAX_PLAYERS - 1) do
        gPlayerObjects[i] = {
            [1] = spawn_non_sync_object(id_bhvSquishySlideSpark, E_MODEL_SLIDE_SPARK, 0, 0, 0,
            function(obj)
                obj.oPlayerIndex = i
            end),
            [2] = spawn_non_sync_object(id_bhvSquishyHeldShell, E_MODEL_KOOPA_SHELL, 0, 0, 0,
            function(obj)
                obj.oPlayerIndex = i
            end)
        }
    end
end

local function on_object_render(obj)
    local m = gMarioStates[obj.oPlayerIndex]
    if obj.behavior ~= nil and get_id_from_behavior(obj.behavior) == id_bhvSquishySlideSpark then
        obj.oFaceAngleYaw = m.faceAngle.y--obj.oFaceAngleYaw + 0x800
        obj.oFaceAnglePitch = 0--obj.oFaceAnglePitch + 0x2800
        obj.oFaceAngleRoll = obj.oFaceAngleRoll + 0x2000
    
        obj.oPosX = get_hand_foot_pos_x(m, 2)
        obj.oPosY = get_hand_foot_pos_y(m, 2) - 10
        obj.oPosZ = get_hand_foot_pos_z(m, 2)
    
        --bhv_squishy_slide_spark_render(obj)
    
        -- if the player is off screen, move the obj to the player origin
        if m.marioBodyState.updateTorsoTime ~= gMarioStates[0].marioBodyState.updateTorsoTime then
            obj.oPosX = m.pos.x
            obj.oPosY = m.pos.y
            obj.oPosZ = m.pos.z
        end
    
        obj.oPosX = obj.oPosX + sins(m.faceAngle.y) * 10
        obj.oPosZ = obj.oPosZ + coss(m.faceAngle.y) * 10
    
        obj.header.gfx.pos.x = obj.oPosX
        obj.header.gfx.pos.y = obj.oPosY
        obj.header.gfx.pos.z = obj.oPosZ
    end

    if obj.behavior ~= nil and get_id_from_behavior(obj.behavior) == id_bhvSquishyHeldShell then
        obj.oFaceAngleYaw = m.faceAngle.y
        --obj.oFaceAnglePitch = 0--obj.oFaceAnglePitch + 0x2800
        --obj.oFaceAngleRoll = obj.oFaceAngleRoll + 0x2000
    
        obj.oPosX = get_hand_foot_pos_x(m, 1)
        obj.oPosY = get_hand_foot_pos_y(m, 1) - 10
        obj.oPosZ = get_hand_foot_pos_z(m, 1)
    
        --bhv_squishy_slide_spark_render(obj)
    
        -- if the player is off screen, move the obj to the player origin
        if m.marioBodyState.updateTorsoTime ~= gMarioStates[0].marioBodyState.updateTorsoTime then
            obj.oPosX = m.pos.x
            obj.oPosY = m.pos.y
            obj.oPosZ = m.pos.z
        end
    
        obj.oPosX = obj.oPosX + sins(m.faceAngle.y) * 10
        obj.oPosZ = obj.oPosZ + coss(m.faceAngle.y) * 10
    
        obj.header.gfx.pos.x = obj.oPosX
        obj.header.gfx.pos.y = obj.oPosY
        obj.header.gfx.pos.z = obj.oPosZ
    end
end

hook_event(HOOK_ON_OBJECT_RENDER, on_object_render)
hook_event(HOOK_ON_SYNC_VALID, on_sync_valid)