shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D paint_grid : filter_nearest, repeat_disable;
uniform sampler2D grass_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D stone_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D snow_texture : source_color, filter_nearest, repeat_enable;
uniform float terrain_size = 160.0;
uniform float texture_repeat = 20.0;

void fragment() {
	float layer = texture(paint_grid, UV).r;
	vec2 tiled_uv = UV * texture_repeat;
	vec3 surface = texture(grass_texture, tiled_uv).rgb;
	if (layer > 0.83) {
		surface = texture(snow_texture, tiled_uv).rgb;
	} else if (layer > 0.50) {
		surface = texture(stone_texture, tiled_uv).rgb;
	} else if (layer > 0.16) {
		surface = texture(dirt_texture, tiled_uv).rgb;
	}
	ALBEDO = surface;
	ROUGHNESS = 1.0;
}
