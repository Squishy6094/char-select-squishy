#include "src/game/envfx_snow.h"

const GeoLayout squishy_cap_wing_geo[] = {
	GEO_NODE_START(),
	GEO_OPEN_NODE(),
		GEO_ANIMATED_PART(LAYER_OPAQUE, 0, 0, -1, squishy_cap_wing_0000_displaylist_mesh_layer_1),
		GEO_OPEN_NODE(),
			GEO_DISPLAY_LIST(LAYER_ALPHA, squishy_cap_wing_0000_displaylist_mesh_layer_4),
			GEO_DISPLAY_LIST(LAYER_TRANSPARENT, squishy_cap_wing_0000_displaylist_mesh_layer_5),
		GEO_CLOSE_NODE(),
	GEO_CLOSE_NODE(),
	GEO_END(),
};
