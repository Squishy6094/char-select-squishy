E_MODEL_SLIDE_SPARK = smlua_model_util_get_id("squishy_slide_spark_geo")

gPlayerObjects = {}
for i = 0, (MAX_PLAYERS - 1) do
    gPlayerObjects[i] = nil
end

------------

define_custom_obj_fields({
    oPlayerIndex = 'u32',
})

function bhv_spark_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oOpacity = 0
    obj.hookRender = 1
    obj_scale(obj, 1)
    obj.hitboxRadius = 100
    obj.hitboxHeight = 100
    obj.oIntangibleTimer = 0
    cur_obj_hide()
end

function bhv_spark_loop(obj)
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

    if m.action == ACT_SQUISHY_SLIDE then
        cur_obj_unhide()
    else
        cur_obj_hide()
    end
end

id_bhvSquishySlideSpark = hook_behavior(nil, OBJ_LIST_DEFAULT, true, bhv_spark_init, bhv_spark_loop)

------------

function on_sync_valid()
    for i = 0, (MAX_PLAYERS - 1) do
        gPlayerObjects[i] = spawn_non_sync_object(id_bhvSquishySlideSpark, E_MODEL_SLIDE_SPARK, 0, 0, 0,
        function(obj)
            obj.oPlayerIndex = i
        end)
    end
end

function dot_along_angle(obj, m, angle)
    local v1 = {
        x = obj.oPosX - m.pos.x,
        y = obj.oPosY - m.pos.y,
        z = obj.oPosZ - m.pos.z,
    }
    vec3f_normalize(v1)
    local v2 = {
        x = sins(m.faceAngle.y + angle),
        y = 0,
        z = coss(m.faceAngle.y + angle),
    }
    return vec3f_dot(v1, v2)
end

function bhv_squishy_slide_spark_render(obj)
    local m = gMarioStates[obj.oPlayerIndex]
    --local e = gMarioStateExtras[obj.oPlayerIndex]
    --local animFrame = m.marioObj.header.gfx.animInfo.animFrame

    if m.action == ACT_SQUISHY_SLIDE then
        obj.oFaceAngleRoll = obj.oFaceAngleRoll + 0x800
        --[[
        if m.actionArg == 1 then
            obj.oFaceAnglePitch = e.rotAngle + 0x9000
            obj.oFaceAngleRoll = 0
        elseif m.actionArg == 0 then
            local pitch = 0x000
            if e.animFrame == 0 then
                pitch = 0x4500
            elseif e.animFrame == 0 then
                pitch = -0x3500
            else
                pitch = -0x5000
            end
            
            obj.oFaceAnglePitch = approach_s32(obj.oFaceAnglePitch, pitch, 0x2800, 0x2800)
        end
    elseif m.action == ACT_AMY_HAMMER_ATTACK then
        local scalar = dot_along_angle(obj, m, 0) * 1.5
        if scalar > 0.723 then scalar = 0.723 end
        obj.oFaceAnglePitch = 0x5000 * scalar + 0x500
        obj.oFaceAngleRoll = 0x1000 * dot_along_angle(obj, m, -0x8000)
        e.rotAngle = obj.oFaceAnglePitch
    elseif m.action == ACT_AMY_HAMMER_POUND or m.action == ACT_AMY_HAMMER_POUND_LAND 
    or (m.action == ACT_AMY_HAMMER_HIT and m.actionArg == 1) then
        obj.oFaceAnglePitch = 0x4000
    elseif m.action == ACT_AMY_HAMMER_SPIN or m.action == ACT_AMY_HAMMER_SPIN_AIR then
        obj.oFaceAnglePitch = 0x4000
        obj.oAnimState = 1
        ]]
    end
end

function on_object_render(obj)
    if get_id_from_behavior(obj.behavior) ~= id_bhvSquishySlideSpark then
        return
    end

    local m = gMarioStates[obj.oPlayerIndex]

    --if not active_player(m) then
    --    return
    --end

    obj.oFaceAngleYaw = m.faceAngle.y--obj.oFaceAngleYaw + 0x800
    obj.oFaceAnglePitch = 0--obj.oFaceAnglePitch + 0x2800
    obj.oFaceAngleRoll = obj.oFaceAngleRoll + 0x2000
    obj.oOpacity = math.min(m.forwardVel/70, 1)*255

    obj.oPosX = get_hand_foot_pos_x(m, 2)
    obj.oPosY = get_hand_foot_pos_y(m, 2) - 10
    obj.oPosZ = get_hand_foot_pos_z(m, 2)

    bhv_squishy_slide_spark_render(obj)

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

hook_event(HOOK_ON_OBJECT_RENDER, on_object_render)
hook_event(HOOK_ON_SYNC_VALID, on_sync_valid)