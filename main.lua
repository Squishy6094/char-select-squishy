-- name: [CS] Squishy
-- description: Omgg the CS dev made a self insert,, why would she do that is she stupid???\n\n\\#ff7777\\Dudee you'd never guess what API this mod needs o.o
-- category: cs

local VERSION_NUM = "1 Pre-Release"

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
            {text = "really now..?", timer = 2.9},
            {text = "hii don't mind me you can't find me anyway", timer = 5.7},
            {text = "skill issue", timer = 2.5},
            {text = "you're silly", timer = 2.6},
            {text = "floralys mussolini is on her way.", timer = 6.9},
        },
        {
            name = "\\#FF6A00\\Mlops\\#FFCC33\\Funny",
            {text = "The Host doesn't need to hear all this, they're a highly trained professional", timer = 9.130},
            {text = "Heh, dumbass.", timer = 3.930},
            {text = "Why do they call it character select when you char a ter select elect er char ter?", timer = 9.430},
            {text = "You're meanin' to tell me you DON'T know what CS stands for?", timer = 7.730},
            {text = "Come back with the api and THEN we'll talk.", timer = 5.830},
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

E_MODEL_SQUISHY = smlua_model_util_get_id("squishy_geo")
E_MODEL_SQUISHY_PLUSH = smlua_model_util_get_id("squishy_plush_geo")
E_MODEL_SQUISHY_BALATRO = smlua_model_util_get_id("squishy_card_geo")

local TEX_ICON_SQUISHY = get_texture_info("squishy-icon")

local CAPS_SQUISHY = {
    normal = smlua_model_util_get_id("squishy_cap_geo"),
    wing = smlua_model_util_get_id("squishy_cap_wing_geo"),
    metal = smlua_model_util_get_id("squishy_cap_metal_geo"),
    metalWing = smlua_model_util_get_id("squishy_cap_metal_geo")
}

local SQUISHY_SKIN_TONE = "FBE7B7"
local squishyPalettes = {
    {
        name = "Default",
        [SHOES] = "1C1C1C",
        [GLOVES] = "BFC72F",
        [EMBLEM] = "FFFFFF",
        [HAIR] = "130D0A",
        [SKIN] = SQUISHY_SKIN_TONE,
        [SHIRT] = "12250B",
        [PANTS] = "0B0E20",
    },
    {
        name = "Soft Sided",
        [PANTS] = "221C1A",
        [SHIRT] = "122020",
        [GLOVES] = "FFFFFF",
        [SHOES] = "4A5462",
        [HAIR] = "3B1725",
        [SKIN] = "E9B5A3",
        [CAP] = "221C1A",
        [EMBLEM] = "FFFFFF",
    },
    {
        name = "Pretttyy",
        [PANTS]  = "0C0A15",
        [SHIRT]  = "1A152C",
        [GLOVES] = "FFFFFF",
        [SHOES]  = "FFFFFF",
        [HAIR]   = "867EDD",
        [SKIN]   = "FEFFFF",
        [CAP]    = "1A152C",
        [EMBLEM] = "8176FF",
    },
    {
        name = "Yo-Yo Girl",
        [PANTS] = "4D463B",
        [SHIRT] = "648CAA",
        [GLOVES] = "EAD382",
        [SHOES] = "648CAA",
        [HAIR] = "F0CE93",
        [SKIN] = SQUISHY_SKIN_TONE,
        [CAP] = "648CAA",
        [EMBLEM] = "EAD382",
    },
    {
        name = "Eastward",
        [PANTS] = "738F17",
        [SHIRT] = "FFB620",
        [GLOVES] = "FFFFFF",
        [SHOES] = "738F17",
        [HAIR] = "8B511E",
        [SKIN] = "AF7A2E",
        [CAP] = "FFB620",
        [EMBLEM] = "FFF03A",
    },
    {
        name = "Modeled",
        [PANTS] = "000000",
        [SHIRT] = "6B86FF",
        [GLOVES] = "291CA8",
        [SHOES] = "000000",
        [HAIR] = "A63404",
        [SKIN] = "FFFFFF",
        [CAP] = "6B86FF",
        [EMBLEM] = "291CA8",
    },
    {
        name = "Rigged",
        [SHOES] = "626262",
        [GLOVES] = "15151C",
        [EMBLEM] = "FFFFFF",
        [HAIR] = "543100",
        [SKIN] = SQUISHY_SKIN_TONE,
        [SHIRT] = "9BE4FF",
        [PANTS] = "70EA81",
    },
    {
        name = "Climber",
        [PANTS] = "92301C",
        [SHIRT] = "265ACD",
        [GLOVES] = "009FCB",
        [SHOES] = "FFF7C2",
        [HAIR] = "FF280F",
        [SKIN] = SQUISHY_SKIN_TONE,
        [CAP] = "4A263D",
        [EMBLEM] = "92301C",
    },
    {
        name = "Pluto",
        [PANTS] = "E90037",
        [SHIRT] = "D25400",
        [GLOVES] = "FFFFFF",
        [SHOES] = "701C0F",
        [HAIR] = "FFC000",
        [SKIN] = SQUISHY_SKIN_TONE,
        [CAP] = "E90037",
        [EMBLEM] = "FFFFFF",
    },
    {
        name = "So True :3",
        [PANTS] = "398FBE",
        [SHIRT] = "B96C86",
        [GLOVES] = "FFFFFF",
        [SHOES] = "620E22",
        [HAIR] = "FF9BCD",
        [SKIN] = SQUISHY_SKIN_TONE,
        [CAP] = "398FBE",
        [EMBLEM] = "FFFFFF",
    },
    {
        name = "Gum",
        [PANTS] = "67606F",
        [SHIRT] = "322C3C",
        [GLOVES] = "FFFFFF",
        [SHOES] = "1A1C1E",
        [HAIR] = "42C689",
        [SKIN] = "F0FFEC",
        [CAP] = "121210",
        [EMBLEM] = "FFFFF9",
    }
}

local COURSE_SQUISHY = {
    top = get_texture_info("squishy-course-top"),
    bottom = get_texture_info("squishy-course-bottom"),
}

local ANIMS_SQUISHY = {
    [CHAR_ANIM_IDLE_HEAD_LEFT] = SQUISHY_ANIM_HEAD_LEFT,
    [CHAR_ANIM_IDLE_HEAD_RIGHT] = SQUISHY_ANIM_HEAD_RIGHT,
    [CHAR_ANIM_IDLE_HEAD_CENTER] = SQUISHY_ANIM_HEAD_CENTER,
    [CHAR_ANIM_CROUCHING] = SQUISHY_ANIM_CROUCHING,
    [CHAR_ANIM_START_CROUCHING] = SQUISHY_ANIM_START_CROUCHING,
    [CHAR_ANIM_STOP_CROUCHING] = SQUISHY_ANIM_STOP_CROUCHING,
    [CHAR_ANIM_CRAWLING] = SQUISHY_ANIM_CRAWLING,
    [CHAR_ANIM_START_CRAWLING] = SQUISHY_ANIM_START_CRAWLING,
    [CHAR_ANIM_STOP_CRAWLING] = SQUISHY_ANIM_STOP_CRAWLING,
    [CHAR_ANIM_START_GROUND_POUND] = SQUISHY_ANIM_START_GROUND_POUND,
    [CHAR_ANIM_GROUND_POUND] = SQUISHY_ANIM_GROUND_POUND,
    [charSelect.CS_ANIM_MENU] = SQUISHY_ANIM_TRICK_TETO
}

CT_SQUISHY = _G.charSelect.character_add("Squishy", {"Creator of Character Select!!", "Transgender ladyy full of", "coderinggg"}, "Squishy / SprSn64", "008800", E_MODEL_SQUISHY, CT_MARIO, TEX_ICON_SQUISHY, 1.1)
_G.charSelect.character_add_caps(E_MODEL_SQUISHY, CAPS_SQUISHY)
_G.charSelect.character_add_course_texture(CT_SQUISHY, COURSE_SQUISHY)
_G.charSelect.character_add_animations(E_MODEL_SQUISHY, ANIMS_SQUISHY)
_G.charSelect.character_set_category(CT_SQUISHY, "Squishy Workshop")

for i = 1, #squishyPalettes do
    _G.charSelect.character_add_palette_preset(E_MODEL_SQUISHY, squishyPalettes[i], squishyPalettes[i].name)
    _G.charSelect.character_add_palette_preset(E_MODEL_SQUISHY_PLUSH, squishyPalettes[i], squishyPalettes[i].name)
end

local MOD_NAME = "Squishy Pack"
_G.charSelect.credit_add(MOD_NAME, "Squishy6094", "Coderingg :3")
_G.charSelect.credit_add(MOD_NAME, "Shell_x33", "Taunts / Prettyy >//<")
_G.charSelect.credit_add(MOD_NAME, "SprSn64", "Squishy Model / Taunts")
_G.charSelect.credit_add(MOD_NAME, "KF", "Model Rigging")
_G.charSelect.credit_add(MOD_NAME, "DM-Kun", "Taunts / Icon")
_G.charSelect.credit_add(MOD_NAME, "Jer", "Taunts / Anims")

local TEXT_VERSION = "[CS] Squishy v" .. tostring(VERSION_NUM)
local opacity = 0
local function hud_render_menu()
    if _G.charSelect.character_get_current_number() ~= CT_SQUISHY then
        opacity = lerp(opacity, 0, 0.1)
    else
        opacity = lerp(opacity, 255, 0.1)
    end
    if opacity < 1 then
        return
    end
    local width = djui_hud_get_screen_width() + 1
    local menuColor = _G.charSelect.get_menu_color()
    local menuColorHalf = {
        r = menuColor.r * 0.5 + 127,
        g = menuColor.g * 0.5 + 127,
        b = menuColor.b * 0.5 + 127
    }

    djui_hud_set_color(menuColorHalf.r, menuColorHalf.g, menuColorHalf.b, opacity)
    djui_hud_set_font(FONT_TINY)
    djui_hud_print_text(TEXT_VERSION, width - 5 - djui_hud_measure_text(TEXT_VERSION)*0.5, 3, 0.5)
end

_G.charSelect.hook_render_in_menu(hud_render_menu)