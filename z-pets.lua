if not _G.wpets then return end

local ID_SQUISHY_PLUSHIE = _G.wpets.add_pet({
	name = "Squishy Plushie", credit = "SprSp64",
	description = "wonderful",
	modelID = E_MODEL_SQUISHY_PLUSH_PET,
	scale = 0.7, yOffset = 0, flying = false
})

_G.wpets.set_pet_anims_head(ID_SQUISHY_PLUSHIE)

_G.wpets.set_pet_sounds(ID_SQUISHY_PLUSHIE, {
	spawn = 'squishy-plushie.ogg',
	happy = 'squishy-plushie.ogg',
	vanish = nil,
	step = nil
})