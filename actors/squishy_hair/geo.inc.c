#include "src/game/envfx_snow.h"

const GeoLayout squishy_hair_geo[] = {
	GEO_NODE_START(),
	GEO_OPEN_NODE(),
		GEO_TRANSLATE_ROTATE(LAYER_OPAQUE, -3, 123, 18, 0, 90, 8),
		GEO_OPEN_NODE(),
			GEO_ANIMATED_PART(LAYER_OPAQUE, 0, 0, 0, squishy_hair_0000_displaylist_mesh_layer_1),
		GEO_CLOSE_NODE(),
		GEO_DISPLAY_LIST(LAYER_OPAQUE, squishy_hair_material_revert_render_settings),
	GEO_CLOSE_NODE(),
	GEO_END(),
};
