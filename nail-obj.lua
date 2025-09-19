
local E_MODEL_SQUISHY_NAIL = smlua_model_util_get_id("squishy_nail_geo")

gPlayerObjects = {}
for i = 0, (MAX_PLAYERS - 1) do
    gPlayerObjects[i] = nil
end

------------

define_custom_obj_fields({
    oPlayerIndex = 'u32',
})

local function bhv_nail_init(obj)
    obj.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj.oOpacity = 0
    obj.hookRender = 1
    obj_scale(obj, 1)
    obj.hitboxRadius = 100
    obj.hitboxHeight = 100
    obj.oIntangibleTimer = 0
    cur_obj_hide()
end

local function bhv_nail_loop(obj)
    local m = gMarioStates[obj.oPlayerIndex]

    -- if the player is off screen, hide the obj
    if m.marioBodyState.updateTorsoTime ~= gMarioStates[0].marioBodyState.updateTorsoTime then
        cur_obj_hide()
        return
    end

    -- update palette
    local np = gNetworkPlayers[obj.oPlayerIndex]
    if np ~= nil then
        obj.globalPlayerIndex = np.globalIndex
    end

    -- check if this should be activated
    if obj_is_hidden(obj) ~= 0 then
        cur_obj_unhide()
        obj_set_model_extended(obj, E_MODEL_SQUISHY_NAIL)
        obj_scale(obj, 1)
        obj.oAnimState = 0
        obj.header.gfx.node.flags = obj.header.gfx.node.flags & ~GRAPH_RENDER_BILLBOARD
        obj.oAnimations = nil
    end

    obj.oFaceAngleYaw = m.faceAngle.y
    obj.oFaceAnglePitch = 0x3000
    obj.oFaceAngleRoll = 0

    obj.oPosX = get_hand_foot_pos_x(m, 0)
    obj.oPosY = get_hand_foot_pos_y(m, 0)
    obj.oPosZ = get_hand_foot_pos_z(m, 0)
    
    -- if the player is off screen, move the obj to the player origin
    if m.marioBodyState.updateTorsoTime ~= gMarioStates[0].marioBodyState.updateTorsoTime then
        obj.oPosX = m.pos.x
        obj.oPosY = m.pos.y
        obj.oPosZ = m.pos.z
    end

    obj.header.gfx.pos.x = obj.oPosX
    obj.header.gfx.pos.y = obj.oPosY
    obj.header.gfx.pos.z = obj.oPosZ
--[[
    if m.action == ACT_SQUISHY_SLIDE and m.actionArg > 0 and m.actionTimer > 5 and m.forwardVel > 60 then
        cur_obj_unhide()
        obj.oOpacity = math.min(m.forwardVel/70, 1)*255
    else
        cur_obj_hide()
    end]]
end

local id_bhvSquishyNail = hook_behavior(nil, OBJ_LIST_DEFAULT, true, bhv_nail_init, bhv_nail_loop, "bhvSquishyNail")

local function on_sync_valid()
    for i = 0, (MAX_PLAYERS - 1) do
        gPlayerObjects[i] = {
            [1] = spawn_non_sync_object(id_bhvSquishyNail, E_MODEL_SQUISHY_NAIL, 0, 0, 0,
            function(obj)
                obj.oPlayerIndex = i
            end),
        }
    end
end

hook_event(HOOK_ON_SYNC_VALID, on_sync_valid)