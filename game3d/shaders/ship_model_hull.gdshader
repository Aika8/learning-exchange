// The hull of the pinnace model (ADR-0036, amendment 3): her own texture, normals and roughness, physically lit,
// with the white bottom paint below the waterline toned down to her dark planking — seen from below in the sky it
// read as a flat white slab. Drawn in the transparent pass, opaque and writing depth, so no island's technique
// redraws it. The model: Poly Haven `ship_pinnace`, CC0. This shader: own work, CC0.
shader_type spatial;
render_mode depth_draw_always, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform float waterline = 0.6;  // metres of the model: below it the paint is toned down
uniform vec3 bottom = vec3(0.16, 0.11, 0.08);  // the planking's dark brown
varying float height;

void vertex() {
	height = VERTEX.y;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float below = 1.0 - smoothstep(waterline - 0.25, waterline + 0.05, height);
	float light = dot(c, vec3(0.3, 0.55, 0.15));
	ALBEDO = mix(c, bottom * (0.6 + light * 0.8), below);  // the grain of the texture stays, its white goes
	vec3 orm = texture(orm_tex, UV).rgb;
	AO = orm.r;
	ROUGHNESS = mix(orm.g, 0.9, below);  // matt below: the smooth paint mirrored the sky
	METALLIC = orm.b;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	ALPHA = 1.0;
}
