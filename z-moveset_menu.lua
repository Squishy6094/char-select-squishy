-- MOVESET DESCRIPTIONS --
-- 'A' : A Button
-- 'B' : B Button
-- 'X' : X Button
-- 'Y' : Y Button
-- 'Z' : Z Trigger
-- 'R' : R Trigger
-- 'L' : L Trigger

-- 'S' : START Button
-- '8' : DPAD Up
-- '2' : DPAD Down
-- '4' : DPAD Left
-- '6' : DPAD Right
-- 'O' : Analog Stick
-- 'C' : C Buttons/Stick

-- 'a' : (press in the air)
-- 'm' : (press while moving)

local movesetMenus = {
    [CT_SQUISHY] = {
        { input = 'Aa',   name = "Trick",         desc = "Perform a random trick. Chain them together for huge cool points! Better not fumble though.." },
        { input = 'Za',   name = "Ground Pound",  desc = "A spinning ground pound! Press [A] just after landing to bounce high." },
        { input = 'ZAa',  name = "Rollout Cancel" },
        { input = 'BZma', name = "Drill Dive",    desc = "Alternative ground pound, performed out of a dive." },
        { input = 'ZB',   name = "Slide Kick",    desc = "Firey slide kick that builds up tons of speed!" },
    }
}

-- CONSTANTS --

local OPT_MOVESETS = _G.charSelect.optionTableRef.localMoveset
local OPT_DEBUG = _G.charSelect.optionTableRef.debugInfo
local OPT_ANIMS = _G.charSelect.optionTableRef.anims

local SCALE_BUTTONS = 0.475
local SCALE_MOVE = 0.4
local SCALE_DESC = 0.275

local TEXT_MOVESET_MENU = "Z - Moveset Guide"

local TEX_BUTTONS = get_texture_info('cs_buttons')
local BUTTON_TILES = {
    A = { x = 0, y = 0, w = 32 },
    B = { x = 32, y = 0, w = 32 },
    X = { x = 64, y = 0, w = 32 },
    Y = { x = 96, y = 0, w = 32 },
    L = { x = 0, y = 32, w = 32 },
    R = { x = 32, y = 32, w = 32 },
    Z = { x = 64, y = 32, w = 32 },
    S = { x = 96, y = 32, w = 32 },
    ['8'] = { x = 0, y = 64, w = 32 },
    ['2'] = { x = 32, y = 64, w = 32 },
    ['4'] = { x = 64, y = 64, w = 32 },
    ['6'] = { x = 96, y = 64, w = 32 },
    O = { x = 0, y = 96, w = 32 },
    C = { x = 32, y = 96, w = 32 },
    a = { x = 96, y = 96, w = 16, mod = true },
    m = { x = 112, y = 96, w = 16, mod = true },
}

-- description and page length calculation

local NUM_PAGES = {}

djui_hud_set_resolution(RESOLUTION_N64)
djui_hud_set_font(FONT_TINY)
for key, menu in pairs(movesetMenus) do
    local totalHeight = 0
    for i, move in ipairs(menu) do
        local height = 20
        if move.desc then
            local type = type(move.desc)
            if type == 'string' then
                local fullDesc = move.desc
                movesetMenus[key][i].desc = {}

                local prevSpaceIndex = 0
                local lastSplitIndex = 1
                local numSplit = 1
                while true do
                    local spaceIndex = string.find(fullDesc, ' ', prevSpaceIndex + 1)

                    if spaceIndex == nil then
                        -- insert the rest of the description into array if end is reached
                        movesetMenus[key][i].desc[numSplit] = string.sub(fullDesc, lastSplitIndex)
                        break
                    end

                    local segment = string.sub(fullDesc, lastSplitIndex, spaceIndex - 1)
                    if djui_hud_measure_text(segment) > 200 then
                        -- create split
                        movesetMenus[key][i].desc[numSplit] = segment

                        lastSplitIndex = spaceIndex + 1
                        numSplit = numSplit + 1
                    end
                    prevSpaceIndex = spaceIndex
                end
                height = 29 + (numSplit - 1) * 8
            elseif type == 'table' then
                height = 29 + (#move.desc - 1) * 8
            end
        end
        totalHeight = totalHeight + height

        movesetMenus[key][i].height = height
        movesetMenus[key][i].page = (totalHeight // 150) + 1
    end
    NUM_PAGES[key] = (totalHeight // 150) + 1
end

--

if not _G.movesetMenu then
    _G.movesetMenu = {}
    _G.movesetMenu.page = 0
    _G.movesetMenu.targetPage = 0
    _G.movesetMenu.scroll = 0.0
    _G.movesetMenu.lastScrollOffset = 108.0
end
local menu = _G.movesetMenu

local function render_menu_rect(x, y, w, h)
    djui_hud_render_rect_interpolated(x + menu.lastScrollOffset, y, w, h, x, y, w, h)
end
local function render_menu_tex_tile(tex, x, y, w, tileX, tileY, tileW)
    w = w * (tileW / 128)
    djui_hud_render_texture_tile_interpolated(tex, x + menu.lastScrollOffset, y, w, w, x, y, w, w, tileX, tileY, tileW,
        tileW)
end
local function print_menu_text(text, x, y, scale)
    djui_hud_print_text_interpolated(text, x + menu.lastScrollOffset, y, scale, x, y, scale)
end

local function char_select_menu_render()
    if _G.charSelect.get_options_status(OPT_MOVESETS) == 1 and _G.charSelect.get_options_status(OPT_DEBUG) == 0 then
        local character = _G.charSelect.character_get_current_number()
        local charMenu = movesetMenus[character]
        if charMenu then
            djui_hud_set_font(FONT_TINY)
            djui_hud_set_resolution(RESOLUTION_N64)

            local menuColor = _G.charSelect.get_menu_color()
            local menuColorHalf = {
                r = menuColor.r * 0.5 + 127,
                g = menuColor.g * 0.5 + 127,
                b = menuColor.b * 0.5 + 127
            }

            local width = djui_hud_get_screen_width() + 1.4
            local height = 240

            local widthScale = maxf(width, 321.4) / 320
            local x = 108 * widthScale
            local textX = width - x * 0.5

            local numPages = NUM_PAGES[character]

            djui_hud_set_color(menuColorHalf.r, menuColorHalf.g, menuColorHalf.b, 255)
            if menu.targetPage > 0 then
                local text = TEXT_MOVESET_MENU .. " (" .. menu.targetPage .. "/" .. numPages .. ")"
                djui_hud_print_text(text, textX - djui_hud_measure_text(text) * 0.25, height - 40, 0.5)
            else
                djui_hud_print_text(TEXT_MOVESET_MENU, textX - djui_hud_measure_text(TEXT_MOVESET_MENU) * 0.25,
                    height - 40, 0.5)
            end

            if menu.page > 0 then
                local scrollOffset = menu.scroll * x

                textX = textX + scrollOffset
                local leftX = width - x + scrollOffset
                local y = 55

                -- BG box
                djui_hud_set_color(menuColorHalf.r * 0.1, menuColorHalf.g * 0.1, menuColorHalf.b * 0.1, 245)
                render_menu_rect(leftX, 50, x - 2, height - 96)

                for i, move in ipairs(charMenu) do
                    -- only render moves on this page
                    if move.page == menu.page then
                        djui_hud_set_color(menuColorHalf.r, menuColorHalf.g, menuColorHalf.b, 255)
                        -- render input icons
                        local inpX = leftX + 1
                        for c = 1, #move.input do
                            local tile = BUTTON_TILES[move.input:sub(c, c)]
                            if tile then
                                if tile.mod then
                                    render_menu_tex_tile(TEX_BUTTONS, inpX, y, SCALE_BUTTONS,
                                        tile.x, tile.y, tile.w)
                                else
                                    inpX = inpX + 2

                                    render_menu_tex_tile(TEX_BUTTONS, inpX, y - 3.5, SCALE_BUTTONS,
                                        tile.x, tile.y, tile.w)
                                    -- +
                                    if c > 1 then
                                        render_menu_tex_tile(TEX_BUTTONS, inpX - 5.5, y + 1, SCALE_BUTTONS,
                                            112, 112, 16)
                                    end
                                end
                                inpX = inpX + tile.w * SCALE_BUTTONS
                            end
                        end

                        -- render move name and description
                        djui_hud_set_font(FONT_ALIASED)
                        print_menu_text(move.name, textX - djui_hud_measure_text(move.name) * SCALE_MOVE / 2,
                            y - 3, SCALE_MOVE)

                        if move.desc then
                            local descY = y + 12
                            for line = 1, #move.desc do
                                print_menu_text(move.desc[line],
                                    textX - djui_hud_measure_text(move.desc[line]) * SCALE_DESC / 2,
                                    descY + 8 * (line - 1), SCALE_DESC)
                            end
                        end

                        djui_hud_set_color(menuColor.r, menuColor.g, menuColor.b, 255)
                        render_menu_rect(leftX, y + move.height - 6, x, 1)

                        y = y + move.height
                    end
                end
                render_menu_rect(leftX, 194, x, 2)
                render_menu_rect(leftX, 50, 2, height - 96)

                -- store for interpolation
                menu.lastScrollOffset = scrollOffset
            end

            if _G.charSelect.controller.buttonPressed & Z_TRIG ~= 0 then
                menu.targetPage = (menu.targetPage + 1) % (numPages + 1)
                play_sound(menu.targetPage > 0 and SOUND_MENU_MESSAGE_APPEAR or SOUND_MENU_MESSAGE_DISAPPEAR,
                    gGlobalSoundSource)
                -- skip 'flipping' the current page on page 0
                if menu.page == 0 then
                    menu.page = menu.targetPage
                    menu.scroll = 1.0
                end
            end

            -- menu animations
            if _G.charSelect.get_options_status(OPT_ANIMS) == 0 then
                menu.page = menu.targetPage
                menu.scroll = 0.0
            else
                -- page flipping
                if menu.page ~= menu.targetPage then
                    if menu.targetPage == 0 then
                        menu.scroll = approach_f32_asymptotic(menu.scroll, 1.0, 0.8)
                        if menu.scroll > 0.9 then
                            menu.page = 0
                        end
                    else
                        menu.scroll = approach_f32_asymptotic(menu.scroll, 0.1, 0.8)
                        if menu.scroll > 0.05 then
                            menu.page = menu.targetPage
                        end
                    end
                else
                    menu.scroll = approach_f32_asymptotic(menu.scroll, 0.0, 0.8)
                end
            end

            if menu.targetPage > NUM_PAGES[character] then
                menu.targetPage = NUM_PAGES[character]
            end
        end
    end
end

_G.charSelect.hook_render_in_menu(char_select_menu_render)
