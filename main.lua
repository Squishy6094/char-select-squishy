-- name: [CS] Squishy
-- description: new and reall
-- category: cs

if not _G.charSelectExists then
    local noCSMessages = {
        {
            name = "\\#008800\\Squishy",
            {text = "Hey turn on Character Select stupid!!", timer = 5.2*30},
            {text = "OOOoooohhhhh you want to turn on character selecttt ooooohhh,,", timer = 7.8*30},
            {text = "Wha,, where's my character selectt?", timer = 4.6*30},
            {text = "OWWWW FUCKKK AUGHH IT HURTSSS!!! I NEED MY API!! OWWWWWWW!!!!", timer = 9.1*30},
        },
        {
            name = "\\#3f48cc\\Trashcam",
            {text = "Hey man I think ya need some of that character select, if not you a bitch!", timer = 11.5*30},
        },
        {
            name = "\\#2b0013\\Fłorałys",
            {text = "really now..?", timer = 3},
            {text = "hii don't mind me you can't find me anyway", timer = 3},
            {text = "skill issue", timer = 3},
            {text = "you're silly", timer = 3},
            {text = "floralys mussolini is on her way.", timer = 3},
        },
    }
    local frameCount = 0
    local rngPerson = (math.random(1, 3) == 3 and math.random(2, #noCSMessages) or 1)
    local rngMessage = math.random(1, #noCSMessages[rngPerson])
    local name = noCSMessages[rngPerson].name
    local message = noCSMessages[rngPerson][rngMessage].text
    local sendTime = noCSMessages[rngPerson][rngMessage].timer + math.random(-30, 30)
    hook_event(HOOK_UPDATE, function ()
        frameCount = frameCount + 1
        if frameCount == sendTime then
            djui_chat_message_create(name.."\\#dcdcdc\\: "..message)
            play_sound(SOUND_MENU_MESSAGE_APPEAR, gLakituState.curPos)
        end
    end)
    return 0
end

local E_MODEL_SQUISHY = smlua_model_util_get_id("squishy_geo")

local PALETTE_SQUISHY = {
    [SHOES] = "1C1C1C",
    [GLOVES] = "BFC72F",
    [EMBLEM] = "FFFFFF",
    [HAIR] = "130D0A",
    [SKIN] = "FBE7B7",
    [SHIRT] = "12250B",
    [PANTS] = "0B0E20",
}

local COURSE_SQUISHY = {
    top = get_texture_info("squishy-course-top"),
    bottom = get_texture_info("squishy-course-bottom"),
}

CT_SQUISHY = _G.charSelect.character_add("Squishy", {"Creator of Character Select!!", "Transgender ladyy full of", "coderinggg"}, "Squishy / SprSn64", "005500", E_MODEL_SQUISHY, CT_MARIO, "S", 1.1, 37)
_G.charSelect.character_add_palette_preset(E_MODEL_SQUISHY, PALETTE_SQUISHY)
if _G.charSelect.character_add_course_texture ~= nil then
    _G.charSelect.character_add_course_texture(CT_SQUISHY, COURSE_SQUISHY)
end

local MOD_NAME = "Squishy Pack"
_G.charSelect.credit_add(MOD_NAME, "Squishy6094", "Coderingg :3")
_G.charSelect.credit_add(MOD_NAME, "SprSn64", "Models")
_G.charSelect.credit_add(MOD_NAME, "Shell_x33", "Textures / Prettyy >//<")