if not _G.charSelectExists then return end

E_MODEL_SLIDE_SPARK = smlua_model_util_get_id("squishy_slide_spark_geo")

gPlayerObjects = {}
for i = 0, (MAX_PLAYERS - 1) do
    gPlayerObjects[i] = nil
end

------------

define_custom_obj_fields({
    oPlayerIndex = 'u32',
    oPrevPosX = 'u32',
    oPrevPosY = 'u32',
    oPrevPosZ = 'u32',
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

    if m.action == ACT_SQUISHY_SLIDE and m.actionArg > 0 and m.actionTimer > 5 and m.forwardVel > 60 then
        cur_obj_unhide()
        obj.oOpacity = math.min(m.forwardVel/70, 1)*255
    else
        cur_obj_hide()
    end
end

local id_bhvSquishySlideSpark = hook_behavior(nil, OBJ_LIST_DEFAULT, true, bhv_spark_init, bhv_spark_loop, "bhvSquishySlideSpark")

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

local id_bhvSquishyHeldShell = hook_behavior(nil, OBJ_LIST_DEFAULT, true, bhv_held_shell_init, bhv_held_shell_loop, "bhvSquishyHeldShell")

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




-- Hair Phys
-- does the crown, which is rewarded for ASN semi-finalists and onwards
local alreadySpawnedCrown = {}

E_MODEL_GOLD_CROWN = smlua_model_util_get_id("squishy_hair_geo")

---@param o Object
function crown_init(o)
    o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    cur_obj_disable_rendering()
end

local stored_mat4 = {}
---@param o Object
function crown_loop(o)
    if o.oBehParams <= 0 or o.oBehParams > MAX_PLAYERS then return end
    ---@type MarioState
    local m = gMarioStates[o.oBehParams - 1]
    if is_player_active(m) == 0 then
        obj_mark_for_deletion(o)
        alreadySpawnedCrown[o.oBehParams] = nil
        return
    end

    -- hook to head; hookprocess value is based on which player
    do_for_mario_head(m.marioObj.header.gfx.sharedChild, function(graphNode)
        graphNode.hookProcess = 0xEA
    end)

    local oGFX = o.header.gfx
    local mGFX = m.marioObj.header.gfx
    o.oOpacity = 255
    o.oAnimState = 1
    if (m.marioBodyState.modelState & MODEL_STATE_NOISE_ALPHA) ~= 0 then
        o.oOpacity = 128
        o.oAnimState = 1
    end
    oGFX.node.flags = mGFX.node.flags
    if _G.charSelect.character_get_current_number(m.playerIndex) ~= CT_SQUISHY then
        cur_obj_disable_rendering()
    elseif m.playerIndex ~= 0 and (m.marioBodyState.updateHeadPosTime < get_global_timer() - 2) then -- disable rendering if not on screen
        cur_obj_disable_rendering()
    end
    o.hookRender = 1
end

-- Place crown
---@param o Object
function on_obj_render(o)
    if obj_has_behavior_id(o, id_bhvMHCrown) == 0 then return end
    if o.oBehParams <= 0 or o.oBehParams > MAX_PLAYERS then return end
    local m = gMarioStates[o.oBehParams-1]
    if not (m and m.marioObj) then return end
    if not stored_mat4[o.oBehParams] then return end
    local mat4 = stored_mat4[o.oBehParams]
    local mGFX = m.marioObj.header.gfx
    local oGFX = o.header.gfx
    oGFX.angle.x = -radians_to_sm64(math.asin(mat4.m21) * 4)
    oGFX.angle.z = -radians_to_sm64(math.atan(-mat4.m01, mat4.m11)) - 0x4000
    oGFX.angle.y = radians_to_sm64(-math.atan(-mat4.m20, mat4.m22))
    oGFX.angle.z = oGFX.angle.z - 1200

    if m.action == ACT_FIRST_PERSON then
        -- don't ask me why they're swapped
        oGFX.angle.x = oGFX.angle.x + m.statusForCamera.headRotation.z
        oGFX.angle.y = oGFX.angle.y + m.statusForCamera.headRotation.y
        oGFX.angle.z = oGFX.angle.z + m.statusForCamera.headRotation.x
    elseif (m.action & ACT_FLAG_WATER_OR_TEXT ~= 0 or m.marioBodyState.allowPartRotation ~= 0) then
        oGFX.angle.x = oGFX.angle.x + m.marioBodyState.headAngle.z
        oGFX.angle.y = oGFX.angle.y + m.marioBodyState.headAngle.y
        oGFX.angle.z = oGFX.angle.z + m.marioBodyState.headAngle.x
    end

    oGFX.scale.y = mGFX.scale.y
    if oGFX.scale.y <= 0 then oGFX.scale.y = 0.01 end
    
    local upBy = -10 * oGFX.scale.y
    local backBy = 23
    local pitch, yaw, roll = oGFX.angle.x, oGFX.angle.y, oGFX.angle.z
    oGFX.pos.x = mat4.m30 + upBy * (sins(yaw) * sins(pitch) * coss(roll) - coss(yaw) * sins(roll)) + (backBy * sins(yaw + 0x4000) * coss(pitch))
    oGFX.pos.y = mat4.m31 + upBy * (coss(pitch) * coss(roll)) + (backBy * sins(pitch))
    oGFX.pos.z = mat4.m32 + upBy * (coss(yaw) * sins(pitch) * coss(roll) + sins(yaw) * sins(roll)) + (backBy * coss(yaw + 0x4000) * coss(pitch))

    -- Hair phys

    local dx = oGFX.pos.x - o.oHomeX
    local dy = oGFX.pos.y - o.oHomeY
    local dz = oGFX.pos.z - o.oHomeZ
    if dx ~= 0 or dz ~= 0 then
        -- Calculate yaw difference between previous and current position
        djui_chat_message_create(tostring(atan2s(dz, dx)*0.01))
        o.oVelZ = o.oVelZ + atan2s(dz, dx)*0.01 + clamp(m.forwardVel*10, -1000, 1000) + math.clamp(-m.vel.y, 0, 70)*50
        oGFX.angle.z = clamp(oGFX.angle.z + o.oVelZ, 0, 0x7000)
        o.oVelX = o.oVelX - atan2s(dz, dx)*0.01
        oGFX.angle.x = clamp(oGFX.angle.x + o.oVelX, -0x3000, 0x3000)
    end
    o.oVelZ = lerp(o.oVelZ, 0, 0.1)
    o.oVelX = lerp(o.oVelX, 0, 0.1)

    -- Store current position for next frame
    o.oHomeX, o.oHomeY, o.oHomeZ = oGFX.pos.x, oGFX.pos.y, oGFX.pos.z

    o.oPosX = oGFX.pos.x
    o.oPosY = oGFX.pos.y
    o.oPosZ = oGFX.pos.z
    o.oFaceAnglePitch = oGFX.angle.x
    o.oFaceAngleYaw = oGFX.angle.y
    o.oFaceAngleRoll = oGFX.angle.z
end

-- This functions calculates where the crown should be placed
---@param graphNode GraphNode
function on_geo_process(graphNode, matStackIndex)
    if graphNode.hookProcess ~= 0xEA then return end
    local m = geo_get_mario_state()
    if m.marioBodyState.mirrorMario then return end
    local camera = gMarioStates[0].area.camera.mtx
    local mat4 = gMat4Zero()
    local camInv = gMat4Zero()
    mtxf_inverse(camInv, camera)
    mtxf_mul(mat4, gMatStack[matStackIndex], camInv)
    stored_mat4[m.playerIndex + 1] = mat4
    --graphNode.hookProcess = 0
end

---@param graphNode GraphNode
function do_for_mario_head(graphNode, func)
    local stopNode = graphNode
    while graphNode do
        -- head is identified by a rotation node, followed by two animated parts
        if graphNode.type == GRAPH_NODE_TYPE_ROTATION then
            if graphNode.children and graphNode.children.type == GRAPH_NODE_TYPE_ANIMATED_PART then
                local checkNode = graphNode.children.children
                if checkNode and checkNode.type == GRAPH_NODE_TYPE_DISPLAY_LIST then
                    -- required for CS characters that wear something around their neck, like a scarf
                    checkNode = checkNode.next
                end
                if checkNode and checkNode.type == GRAPH_NODE_TYPE_ANIMATED_PART then
                    func(checkNode)
                    return
                end
            end
        end
        
        if graphNode.children then
            do_for_mario_head(graphNode.children, func)
        end
        graphNode = graphNode.next
        if graphNode == stopNode then break end
    end
end

id_bhvMHCrown = hook_behavior(nil, OBJ_LIST_DEFAULT, true, crown_init, crown_loop, "bhvSquishyHair")

function get_crown(i)
    return E_MODEL_GOLD_CROWN
end

function spawn_new_crowns()
    --gPlayerSyncTable[0].role = gPlayerSyncTable[0].role | 64
    --gPlayerSyncTable[0].placementASN = 2
    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        local crownModel = get_crown(i)

        if (not alreadySpawnedCrown[i + 1]) and is_player_active(m) ~= 0 and crownModel then
            local o = obj_get_first_with_behavior_id_and_field_f32(id_bhvMHCrown, 0x40, i + 1) -- oBehParams
            if not o then
                o = spawn_non_sync_object(id_bhvMHCrown, crownModel, m.pos.x, m.pos.y, m.pos.z, nil)
                o.oBehParams = i + 1
                o.globalPlayerIndex = network_global_index_from_local(i)
                alreadySpawnedCrown[i + 1] = 1
            end
        end
    end
end

function reset_spawned()
    alreadySpawnedCrown = {}
end

hook_event(HOOK_UPDATE, spawn_new_crowns)
hook_event(HOOK_ON_SYNC_VALID, reset_spawned)
hook_event(HOOK_ON_OBJECT_RENDER, on_obj_render)
hook_event(HOOK_ON_GEO_PROCESS, on_geo_process)

-- gets distance, pitch, and yaw between two points
function vec3f_get_dist_and_angle_lua(from, to)
    local x = to.x - from.x
    local y = to.y - from.y
    local z = to.z - from.z

    dist = math.sqrt(x * x + y * y + z * z)
    pitch = atan2s(math.sqrt(x * x + z * z), y)
    yaw = atan2s(z, x)
    return dist, pitch, yaw
end