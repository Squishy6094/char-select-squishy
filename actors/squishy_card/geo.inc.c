#include "src/game/envfx_snow.h"

const GeoLayout squishy_card_geo[] = {
	GEO_NODE_START(),
	GEO_OPEN_NODE(),
		GEO_DISPLAY_LIST(LAYER_TRANSPARENT, squishy_card_squishy_card_mesh_layer_5),
	GEO_CLOSE_NODE(),
	GEO_END(),
};
