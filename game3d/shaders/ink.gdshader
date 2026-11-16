// The ink post-effect (ADR-0024): one full-screen quad. mode 1 = a dark outline on depth and normal edges over the
// flat colours; mode 2 = an engraving — paper and ink only, hatching by brightness, plus the outline.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform int mode = 1;
uniform vec3 ink : source_color = vec3(0.13, 0.1, 0.09);
uniform vec3 paper : source_color = vec3(0.93, 0.87, 0.75);
uniform float width = 1.3;  // line width in pixels at 1080p

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float eye_depth(vec2 uv, mat4 inv_projection) {
	vec4 v = inv_projection * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = width * (VIEWPORT_SIZE.y / 1080.0) / VIEWPORT_SIZE;
	float d = eye_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n = texture(normal_tex, SCREEN_UV).rgb * 2.0 - 1.0;
	float dd = 0.0;
	float dn = 0.0;
	vec2 offs[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offs[i] * px;
		dd += abs(eye_depth(uv, INV_PROJECTION_MATRIX) - d);
		dn += 1.0 - dot(texture(normal_tex, uv).rgb * 2.0 - 1.0, n);
	}
	// a depth step counts relative to the distance, so far islands do not turn black
	float edge = max(smoothstep(0.035, 0.07, dd / max(d, 0.5)), smoothstep(0.5, 0.9, dn));
	edge *= 1.0 - smoothstep(180.0, 420.0, d);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	if (mode == 2) {
		// the screen is linear light: bring it to what the eye sees before choosing the strokes
		float lum = pow(clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0), 0.45);
		float s = VIEWPORT_SIZE.y / 1080.0;
		float a = fract((FRAGCOORD.x + FRAGCOORD.y) / (9.0 * s));
		float b = fract((FRAGCOORD.x - FRAGCOORD.y) / (9.0 * s));
		float c = fract(FRAGCOORD.y / (6.0 * s));
		float sky = smoothstep(600.0, 900.0, d);  // the sky stays clean paper
		float hatch = 0.0;
		hatch = max(hatch, step(lum, 0.58) * step(a, 0.22));  // one set of strokes in the half-tones
		hatch = max(hatch, step(lum, 0.4) * step(b, 0.24));   // crossed in the shadows
		hatch = max(hatch, step(lum, 0.24) * step(c, 0.4));   // and a third in the dark
		hatch *= 1.0 - sky;
		vec3 sheet = paper * (0.94 + 0.06 * smoothstep(0.3, 0.9, lum));
		ALBEDO = mix(sheet, ink, max(hatch, edge));
	} else {
		ALBEDO = mix(col, ink, edge * 0.92);
	}
}
