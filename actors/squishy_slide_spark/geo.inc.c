#include "src/game/envfx_snow.h"

const GeoLayout squishy_slide_spark_geo[] = {
	GEO_NODE_START(),
	GEO_OPEN_NODE(),
		GEO_DISPLAY_LIST(LAYER_ALPHA, squishy_slide_spark_Cone_mesh_layer_4),
	GEO_CLOSE_NODE(),
	GEO_END(),
};