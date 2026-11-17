// The ink post-effect (ADR-0024): one full-screen quad. mode 1 = a dark outline on depth and normal edges over the
// flat colours; mode 2 = an engraving — paper and ink only, hatching by brightness, plus the outline.
// Each island is drawn in its own technique (ADR-0026): 0 = ink (the above), 1 = dye — printed silk: colours
// sorted into four dye baths, a light resist line, a weave over everything.
// It draws with two styles at once (ADR-0025): the island's, and `*_from` for what stands in a small column round
// the captain above the height `wave` — the captain still drawn the way the island they came from is drawn.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform int mode = 1;
uniform vec3 ink : source_color = vec3(0.13, 0.1, 0.09);
uniform vec3 paper : source_color = vec3(0.93, 0.87, 0.75);
uniform vec3 tint = vec3(1.0);
uniform float width = 1.3;  // line width in pixels at 1080p
uniform float min_px = 1.0;  // and never thinner than this (small pictures: comic frames)
uniform float hatch_turn = 0.0;
uniform float hatch_gap = 9.0;
uniform int technique = 0;
uniform vec3 ramp0 : source_color = vec3(0.07, 0.09, 0.27);  // the technique's own colours, dark to light
uniform vec3 ramp1 : source_color = vec3(0.16, 0.42, 0.55);
uniform vec3 ramp2 : source_color = vec3(0.86, 0.52, 0.56);
uniform vec3 ramp3 : source_color = vec3(0.97, 0.93, 0.84);
uniform int technique_from = 0;
uniform vec3 ramp0_from : source_color = vec3(0.07, 0.09, 0.27);
uniform vec3 ramp1_from : source_color = vec3(0.16, 0.42, 0.55);
uniform vec3 ramp2_from : source_color = vec3(0.86, 0.52, 0.56);
uniform vec3 ramp3_from : source_color = vec3(0.97, 0.93, 0.84);
uniform vec3 ink_from : source_color = vec3(0.13, 0.1, 0.09);
uniform vec3 paper_from : source_color = vec3(0.93, 0.87, 0.75);
uniform vec3 tint_from = vec3(1.0);
uniform float width_from = 1.3;
uniform float hatch_turn_from = 0.0;
uniform float hatch_gap_from = 9.0;
uniform vec3 column = vec3(0.0);  // the captain's feet, world space
uniform float column_radius = 0.0;  // 0 = one style only
uniform float wave = 0.0;  // world height the new style has reached
uniform vec3 glow : source_color = vec3(1.0, 0.8, 0.4);
uniform float glow_amount = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 view_at(vec2 uv, mat4 inv_projection) {
	vec4 v = inv_projection * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	return v.xyz / v.w;
}

void fragment() {
	vec2 offs[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
	vec3 here = view_at(SCREEN_UV, INV_PROJECTION_MATRIX);
	float d = -here.z;
	// which style: by the nearest thing within the widest line, so a silhouette line belongs to the body in front
	float old = 0.0;
	float band = 0.0;
	if (column_radius > 0.0) {
		vec3 nearest = here;
		vec2 reach = max(width, width_from) * (VIEWPORT_SIZE.y / 1080.0) / VIEWPORT_SIZE;
		for (int i = 0; i < 4; i++) {
			vec3 v = view_at(SCREEN_UV + offs[i] * reach, INV_PROJECTION_MATRIX);
			if (v.z > nearest.z) {
				nearest = v;
			}
		}
		vec3 world = (INV_VIEW_MATRIX * vec4(nearest, 1.0)).xyz;
		float inside = step(length(world.xz - column.xz), column_radius) * step(column.y + 0.06, world.y) * step(world.y, column.y + 2.7);
		old = inside * step(wave, world.y);
		band = inside * exp(-pow((world.y - wave) / 0.1, 2.0));
	}
	float w = mix(width, width_from, old);
	vec3 line = mix(ink, ink_from, old);
	vec2 px = max(w * (VIEWPORT_SIZE.y / 1080.0), min_px) / VIEWPORT_SIZE;
	vec3 n = texture(normal_tex, SCREEN_UV).rgb * 2.0 - 1.0;
	float dd = 0.0;
	float dn = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offs[i] * px;
		dd += abs(-view_at(uv, INV_PROJECTION_MATRIX).z - d);
		dn += 1.0 - dot(texture(normal_tex, uv).rgb * 2.0 - 1.0, n);
	}
	// a depth step counts relative to the distance, so far islands do not turn black
	float edge = max(smoothstep(0.035, 0.07, dd / max(d, 0.5)), smoothstep(0.5, 0.9, dn));
	edge *= 1.0 - smoothstep(180.0, 420.0, d);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb * mix(tint, tint_from, old);
	// the screen is linear light: bring it to what the eye sees before choosing strokes or dye baths
	float lum = pow(clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0), 0.45);
	float s = VIEWPORT_SIZE.y / 1080.0;
	int tech = old > 0.5 ? technique_from : technique;
	vec3 sheet_colour = mix(paper, paper_from, old);
	vec3 result;
	if (tech == 1) {
		// printed silk: four dye baths by brightness, a little of the thing's own colour kept, a light line
		vec3 r0 = mix(ramp0, ramp0_from, old);
		vec3 r1 = mix(ramp1, ramp1_from, old);
		vec3 r2 = mix(ramp2, ramp2_from, old);
		vec3 r3 = mix(ramp3, ramp3_from, old);
		vec3 bath = mix(r0, r1, smoothstep(0.30, 0.33, lum));
		bath = mix(bath, r2, smoothstep(0.50, 0.53, lum));
		bath = mix(bath, r3, smoothstep(0.74, 0.77, lum));
		if (mode == 2) {
			// a two-colour print: indigo on cream
			float tone = smoothstep(0.30, 0.33, lum) * 0.16 + smoothstep(0.50, 0.53, lum) * 0.3 + smoothstep(0.74, 0.77, lum) * 0.54;
			result = mix(r0, sheet_colour, tone);
			line = mix(sheet_colour, r0, smoothstep(0.5, 0.53, lum));  // the line shows on dark and on light cloth
		} else {
			result = mix(bath, col, 0.28);
		}
		vec2 thread = FRAGCOORD.xy / (2.2 * s);
		result *= 0.95 + 0.05 * sin(thread.x * 3.14159) * sin(thread.y * 3.14159);
		result = mix(result, line, edge * 0.95);
	} else if (mode == 2) {
		float turn = mix(hatch_turn, hatch_turn_from, old);
		float gap = mix(hatch_gap, hatch_gap_from, old) * s;
		vec2 p = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * FRAGCOORD.xy;
		float a = fract((p.x + p.y) / gap);
		float b = fract((p.x - p.y) / gap);
		float c = fract(p.y / (gap * 0.667));
		float sky = smoothstep(600.0, 900.0, d);  // the sky stays clean paper
		float hatch = 0.0;
		hatch = max(hatch, step(lum, 0.58) * step(a, 0.22));  // one set of strokes in the half-tones
		hatch = max(hatch, step(lum, 0.4) * step(b, 0.24));   // crossed in the shadows
		hatch = max(hatch, step(lum, 0.24) * step(c, 0.4));   // and a third in the dark
		hatch *= 1.0 - sky;
		vec3 sheet = sheet_colour * (0.94 + 0.06 * smoothstep(0.3, 0.9, lum));
		result = mix(sheet, line, max(hatch, edge));
	} else {
		result = mix(col, line, edge * 0.92);
	}
	// the wave itself: the line it passes over lights up, the surface a little
	ALBEDO = mix(result, glow * 1.6, clamp(band * glow_amount * (0.35 + 0.65 * edge), 0.0, 1.0));
}
