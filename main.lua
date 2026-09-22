-- name: [CS] \\#008800\\Squishy
-- description: Omgg the CS dev made a self insert,, why would she do that is she stupid???\n\n\\#ff7777\\Dudee you'd never guess what API this mod needs o.o
-- category: cs

local VERSION_NUM = "2 Pre-Release"

if not _G.charSelectExists then
    local noCSMessages = {
        {
            name = "\\#008800\\Squishy",
            {text = "Hey turn on Character Select stupid!!", timer = 5.2},
            {text = "OOOoooohhhhh you want to turn on character selecttt ooooohhh,,", timer = 7.8},
            {text = "Wha,, where's my character selectt?", timer = 4.6},
            {text = "OWWWW FUCKKK AUGHH IT HURTSSS!!! I NEED MY API!! OWWWWWWW!!!!", timer = 9.1},
        },
        {
            name = "\\#3f48cc\\Trashcam",
            {text = "Hey man I think ya need some of that character select, if not you a bitch!", timer = 11.5},
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
    local rngPerson = ((math.random(1, 3) == 3) and math.random(2, #noCSMessages) or 1)
    local rngMessage = math.random(1, #noCSMessages[rngPerson])
    local name = noCSMessages[rngPerson].name
    local message = noCSMessages[rngPerson][rngMessage].text
    local sendTime = math.floor(noCSMessages[rngPerson][rngMessage].timer*30 + math.random(-30, 30))
    hook_event(HOOK_UPDATE, function ()
        frameCount = frameCount + 1
        if frameCount == sendTime then
            djui_chat_message_create(name.."\\#dcdcdc\\: "..message)
            log_to_console("[CHARACTER_SELECT_SQUISHY] "..name..": "..message)
            play_sound(SOUND_MENU_MESSAGE_APPEAR, gLakituState.curPos)
        end
    end)
    return 0
end

-- Character Models
E_MODEL_SQUISHY = smlua_model_util_get_id("squishy_geo")
E_MODEL_SHELL = smlua_model_util_get_id("player_shell_geo")

-- Enemy/Object Models
E_MODEL_STUMPA = smlua_model_util_get_id("stumpa_geo")

TEX_SQUISHY = get_texture_info("squishy-icon")

local CAPS_SQUISHY = {
    normal = smlua_model_util_get_id("squishy_cap_geo"),
    wing = smlua_model_util_get_id("squishy_cap_wing_geo"),
    metal = smlua_model_util_get_id("squishy_cap_metal_geo"),
    metalWing = smlua_model_util_get_id("squishy_cap_metal_wing_geo")
}
local VOICETABLE_SQUISHY = {nil}

local SQUISHY_SKIN_TONE = "f3b789"
local PALETTES_SQUISHY = {
    {
        name = "Default",
        [SHOES] = "363636",
        [GLOVES] = "d5c600",
        [EMBLEM] = "FFFFFF",
        [HAIR] = "3d2121",
        [SKIN] = SQUISHY_SKIN_TONE,
        [SHIRT] = "0e2502",
        [CAP] = "2a2a30",
        [PANTS] = "121331",
    },
}

local PALETTES_SHELL = {
    {
        name = "The Classic",
        [HAIR] = "d7d3ff",
        [EMBLEM] = "d7d3ff",
        [SKIN] = "ffffff",
        [SHIRT] = "d7d3ff",
        [GLOVES] = "34305f",
        [PANTS] = "373090",
        [CAP] = "6b5eff",
        [SHOES] = "ffffff",
    },
    {
        name = "Evil",
        [HAIR] = "eea9af",
        [EMBLEM] = "eea9af",
        [SKIN] = "ffffff",
        [SHIRT] = "eea9af",
        [GLOVES] = "4e2d40",
        [PANTS] = "861c41",
        [CAP] = "d95763",
        [SHOES] = "ffffff",
    },
    {
        name = "Gorgeous Lady",
        [HAIR] = "3d2121",
        [EMBLEM] = "de784f",
        [SKIN] = "f3b789",
        [SHIRT] = "d5c600",
        [GLOVES] = "0e2502",
        [PANTS] = "121331",
        [CAP] = "2a2a30",
        [SHOES] = "ffffff",
    },
    {
        name = "Beautiful Lady",
        [HAIR] = "77334c",
        [EMBLEM] = "c16549",
        [SKIN] = "d59b6d",
        [SHIRT] = "cb1a50",
        [GLOVES] = "81092c",
        [PANTS] = "100f1d",
        [CAP] = "433f5f",
        [SHOES] = "ffffff",
    },
    {
        name = "Shader Issues",
        [HAIR] = "02026c",
        [EMBLEM] = "9c0c0c",
        [SKIN] = "ff1010",
        [SHIRT] = "00ff00",
        [GLOVES] = "0000ff",
        [PANTS] = "023a02",
        [CAP] = "007e00",
        [SHOES] = "ffffff",
    },
    {
        name = "Wii-core",
        [HAIR] = "8b8b8b",
        [EMBLEM] = "d7d4d5",
        [SKIN] = "ffffff",
        [SHIRT] = "71e9ff",
        [GLOVES] = "00adcd",
        [PANTS] = "8b8b8b",
        [CAP] = "0095c7",
        [SHOES] = "ffffff",
    },
    {
        name = "Popstar",
        [HAIR] = "f971a6",
        [EMBLEM] = "f971a6",
        [SKIN] = "fea2df",
        [SHIRT] = "ffc332",
        [GLOVES] = "d60053",
        [PANTS] = "5d1213",
        [CAP] = "ff1783",
        [SHOES] = "ffffff",
    },
    {
        name = "Dream Breaker",
        [HAIR] = "767676",
        [EMBLEM] = "767676",
        [SKIN] = "a7a8af",
        [SHIRT] = "e3d187",
        [GLOVES] = "2f2f2f",
        [PANTS] = "0d0d0d",
        [CAP] = "e8e8e8",
        [SHOES] = "ffffff",
    },
    {
        name = "Freshly Clicked",
        [HAIR] = "5c2c21",
        [EMBLEM] = "5c2c21",
        [SKIN] = "caa569",
        [SHIRT] = "5c2c21",
        [GLOVES] = "93612d",
        [PANTS] = "2e100a",
        [CAP] = "b88746",
        [SHOES] = "ffffff",
    },
    {
        name = "Heavy Hitter",
        [HAIR] = "864871",
        [EMBLEM] = "f38f66",
        [SKIN] = "ffd8c3",
        [SHIRT] = "ffffff",
        [GLOVES] = "6a03d2",
        [PANTS] = "110e25",
        [CAP] = "906cc9",
        [SHOES] = "ffffff",
    },
    {
        name = "Banshee",
        [HAIR] = "c2aef6",
        [EMBLEM] = "d8afa9",
        [SKIN] = "f5e7e7",
        [SHIRT] = "ffffff",
        [GLOVES] = "343749",
        [PANTS] = "866e74",
        [CAP] = "56477c",
        [SHOES] = "ffffff",
    },
    {
        name = "Hendschel",
        [HAIR] = "ff1010",
        [EMBLEM] = "ff1010",
        [SKIN] = "ff1010",
        [SHIRT] = "ff1010",
        [GLOVES] = "ff1010",
        [PANTS] = "ff1010",
        [CAP] = "ff1010",
        [SHOES] = "ff1010",
    },
}

-- Custom Eye States
SHELL_EYES_WINK = 9

local ANIMS_SQUISHY = {
    [CHAR_ANIM_IDLE_HEAD_LEFT] = GAMEMODE_ACTIVE and ANIM_SQUISHY_IDLE_GAMEMODE or SQUISHY_ANIM_HEAD_LEFT,
    [CHAR_ANIM_IDLE_HEAD_RIGHT] = GAMEMODE_ACTIVE and ANIM_SQUISHY_IDLE_GAMEMODE or SQUISHY_ANIM_HEAD_RIGHT,
    [CHAR_ANIM_IDLE_HEAD_CENTER] = GAMEMODE_ACTIVE and ANIM_SQUISHY_IDLE_GAMEMODE or SQUISHY_ANIM_HEAD_CENTER,
    [CHAR_ANIM_RUNNING] = SQUISHY_ANIM_RUNNING,
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

local EYES_SQUISHY = {
    [charSelect.CS_ANIM_MENU] = MARIO_EYES_LOOK_RIGHT
}

local ANIMS_SHELL = {
}

local EYES_SHELL = {
    [charSelect.CS_ANIM_MENU] = SHELL_EYES_WINK,
    [CHAR_ANIM_FIRST_PERSON] = SHELL_EYES_WINK,
    [CHAR_ANIM_STAR_DANCE] = SHELL_EYES_WINK,
}

-- Squishy Character
CT_SQUISHY = _G.charSelect.character_add("Squishy", "Creator of Character Select!! Transgender ladyy full of coderinggg", "Squishy / Denpakai", "008800", E_MODEL_SQUISHY, CT_MARIO, TEX_SQUISHY, 1.4)
_G.charSelect.character_add_caps(E_MODEL_SQUISHY, CAPS_SQUISHY)
--_G.charSelect.character_add_animations(E_MODEL_SQUISHY, ANIMS_SQUISHY, EYES_SQUISHY)
_G.charSelect.character_add_voice(E_MODEL_SQUISHY, VOICETABLE_SQUISHY)
_G.charSelect.character_set_category(CT_SQUISHY, "Squishy Workshop", true)
for i = 1, #PALETTES_SQUISHY do
    _G.charSelect.character_add_palette_preset(E_MODEL_SQUISHY, PALETTES_SQUISHY[i], PALETTES_SQUISHY[i].name)
end

_G.charSelect.character_add_model_replacement(CT_SQUISHY, id_bhvGoomba, E_MODEL_STUMPA)
-- Shell Character
CT_SHELL = _G.charSelect.character_add("Shell", "Lalala QUEERR!!!", "Squishy / Jer", "6b5eff", E_MODEL_SHELL, CT_LUIGI, "S", 1.1)
_G.charSelect.character_add_voice(E_MODEL_SHELL, VOICETABLE_SQUISHY)
_G.charSelect.character_set_category(CT_SHELL, "Squishy Workshop", true)
_G.charSelect.character_add_animations(E_MODEL_SHELL, ANIMS_SHELL, EYES_SHELL)
for i = 1, #PALETTES_SHELL do
    _G.charSelect.character_add_palette_preset(E_MODEL_SHELL, PALETTES_SHELL[i], PALETTES_SHELL[i].name)
end

local MOD_NAME = "Squishy Pack"
_G.charSelect.credit_add(MOD_NAME, "Squishy6094", "Coderingg :3")
_G.charSelect.credit_add(MOD_NAME, "Shell_x33", "Beautiful")
_G.charSelect.credit_add(MOD_NAME, "Denpakai", "Squishy Model")
_G.charSelect.credit_add(MOD_NAME, "JerThePear", "Shell Model")

--[[
_G.charSelect.character_add_texture_replacement(CT_SQUISHY, "generic_09005800", get_texture_info("squishy_bob_texture_grass"))
_G.charSelect.character_add_texture_replacement(CT_SQUISHY, "generic_09009800", get_texture_info("squishy_bob_texture_path"))
_G.charSelect.character_add_texture_replacement(CT_SQUISHY, "generic_09009000", get_texture_info("squishy_bob_texture_rockwall"))
_G.charSelect.character_add_texture_replacement(CT_SQUISHY, "generic_0900A000", get_texture_info("squishy_bob_texture_dirt"))
]]
