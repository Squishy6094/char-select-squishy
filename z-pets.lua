if not _G.wpets then return end

local E_MODEL_SQUISHY_PLUSHIE = smlua_model_util_get_id('squishy_plush_geo')

local ID_SQUISHY_PLUSHIE = _G.wpets.add_pet({
	name = "Squishy Plushie", credit = "SprSp64",
	description = "wonderful",
	modelID = E_MODEL_SQUISHY_PLUSHIE,
	scale = 0.7, yOffset = 0, flying = false
})

_G.wpets.set_pet_anims_head(ID_SQUISHY_PLUSHIE)

--[[
_G.wpets.set_pet_sounds(ID_SQUISHY_PLUSHIE, {
	spawn = 'happy.mp3',
	happy = 'happy.mp3',
	vanish = nil,
	step = nil
})
]]