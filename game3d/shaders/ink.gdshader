// The ink post-effect (ADR-0024): one full-screen quad. mode 1 = a dark outline on depth and normal edges over the
// flat colours; mode 2 = an engraving — paper and ink only, hatching by brightness, plus the outline.
// Each island is drawn in its own technique (ADR-0026, ADR-0029): 0 = ink (the above);
// 1 = katazome — a Japanese stencil-resist print in the looser manner of sheet 28: several blues, sand and ochre
//     for rock and timber, rust for cloth, cream paper, soft half-tones; large faint patterns only on cloth, roofs
//     and the cloud sea, laid out in world space (on the hero: in the hero's own space) and faded before they are
//     small enough to shimmer; a thin indigo line; a cotton weave;
// 2 = aquarelle — pen and watercolour: a thin trembling line, washes that run past it, a lot of bare paper, a
//     violet-grey wash for shade, paper grain.
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
uniform vec3 hero = vec3(0.0);  // where the captain stands: a technique that needs object space measures from here
uniform float hero_radius = 0.0;  // 0 = no hero in this scene
uniform vec3 column = vec3(0.0);  // the captain's feet, world space
uniform float column_radius = 0.0;  // 0 = one style only
uniform float wave = 0.0;  // world height the new style has reached
uniform vec3 glow : source_color = vec3(1.0, 0.8, 0.4);
uniform float glow_amount = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float blot(vec2 p) {  // soft value noise: the uneven pools of a watercolour wash
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Seigaiha, the wave pattern: rows of overlapping discs with rings in them. 1 where the stencil is cut.
float seigaiha(vec2 q) {
	float j0 = floor(q.y * 2.0) - 1.0;
	for (int k = 0; k < 3; k++) {
		float j = j0 + float(k);
		float off = 0.5 * mod(j, 2.0);
		vec2 c = vec2(floor(q.x - off + 0.5) + off, j * 0.5);
		float r = length(q - c);
		if (r < 0.5) {
			return step(abs(fract(r * 6.0) - 0.5), 0.2);
		}
	}
	return 0.0;
}

// Nested diamonds for walls, dots for what leans.
float diamonds(vec2 q) {
	vec2 f = abs(fract(q) - 0.5);
	return step(abs(fract((f.x + f.y) * 3.0) - 0.5), 0.17);
}

float dots(vec2 q) {
	vec2 f = fract(q + vec2(0.5 * mod(floor(q.y), 2.0), 0.0)) - 0.5;
	return step(length(f), 0.2);
}

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
	float s = VIEWPORT_SIZE.y / 1080.0;
	int tech = old > 0.5 ? technique_from : technique;
	vec2 px = w * s / VIEWPORT_SIZE;
	vec2 at = SCREEN_UV;
	if (tech == 2) {  // a hand's line is never quite where the edge is
		vec2 t = FRAGCOORD.xy / (34.0 * s);
		at += (vec2(blot(t), blot(t + 23.0)) - 0.5) * 3.2 * s / VIEWPORT_SIZE;
	}
	vec3 n = texture(normal_tex, at).rgb * 2.0 - 1.0;
	float d_at = -view_at(at, INV_PROJECTION_MATRIX).z;
	float dd = 0.0;
	float dn = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 uv = at + offs[i] * px;
		dd += abs(-view_at(uv, INV_PROJECTION_MATRIX).z - d_at);
		dn += 1.0 - dot(texture(normal_tex, uv).rgb * 2.0 - 1.0, n);
	}
	// a depth step counts relative to the distance, so far islands do not turn black
	float edge = max(smoothstep(0.035, 0.07, dd / max(d, 0.5)), smoothstep(0.5, 0.9, dn));
	edge *= 1.0 - smoothstep(180.0, 420.0, d);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb * mix(tint, tint_from, old);
	// the screen is linear light: bring it to what the eye sees before choosing strokes or dye baths
	float lum = pow(clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0), 0.45);
	vec3 sheet_colour = mix(paper, paper_from, old);
	vec3 result;
	if (tech == 1) {
		// Katazome in the looser manner of sheet 28: several blues, a sand and an ochre for rock and timber, rust
		// for cloth and accents, cream paper; soft half-tones; patterns only on big things, large and faint.
		vec3 deep = line;  // the deep indigo is also the line
		vec3 mid_blue = mix(ramp0, ramp0_from, old);
		vec3 pale_blue = mix(ramp1, ramp1_from, old);
		vec3 rust = mix(ramp2, ramp2_from, old);
		vec3 ochre = mix(ramp3, ramp3_from, old);
		vec3 cream = sheet_colour;
		vec3 sand = mix(ochre, cream, 0.6);
		float far = smoothstep(500.0, 900.0, d);
		vec3 world = (INV_VIEW_MATRIX * vec4(here, 1.0)).xyz;
		vec3 anchored = world;
		if (hero_radius > 0.0 && length(world.xz - hero.xz) < hero_radius && world.y > hero.y + 0.05 && world.y < hero.y + 2.7) {
			anchored -= hero;  // on the hero the pattern is measured from the hero
		}
		vec3 wn = normalize(mat3(INV_VIEW_MATRIX) * n);
		vec3 seen = pow(clamp(col, 0.0, 1.0), vec3(0.45));  // as the eye sees it
		float chroma = max(seen.r, max(seen.g, seen.b)) - min(seen.r, min(seen.g, seen.b));
		// which family of dyes: earth (rock, timber, the grass of the ground) or blue (everything else)
		float earthy = smoothstep(0.02, 0.1, seen.r - seen.b) * step(seen.g, seen.r * 1.02);
		float leafy = step(seen.r, seen.g) * step(seen.b, seen.g) * step(0.08, chroma);
		float ground = step(0.75, wn.y) * step(-30.0, world.y) * leafy;  // the grass underfoot is sand, lit or in shade
		float in_shade = step(0.75, wn.y) * step(-30.0, world.y) * (1.0 - smoothstep(0.3, 0.5, lum));
		float warm = clamp(earthy + ground + in_shade, 0.0, 1.0);
		// soft half-tones: four tones a family, with wide, gentle steps between them
		vec3 blue = mix(deep, mid_blue, smoothstep(0.22, 0.36, lum));
		blue = mix(blue, pale_blue, smoothstep(0.42, 0.58, lum));
		blue = mix(blue, cream, smoothstep(0.66, 0.84, lum));
		vec3 earth = mix(deep, ochre * 0.72, smoothstep(0.16, 0.30, lum));
		earth = mix(earth, ochre, smoothstep(0.34, 0.50, lum));
		earth = mix(earth, sand, smoothstep(0.54, 0.70, lum));
		earth = mix(earth, cream, smoothstep(0.86, 0.99, lum));
		result = mix(blue, earth, warm);
		// cloth, and anything truly red, is dyed rust; cool cloth stays blue
		float red = step(1.6 * max(seen.g, seen.b), seen.r) * step(0.2, seen.r - min(seen.g, seen.b));
		float upright = 1.0 - smoothstep(0.2, 0.35, abs(wn.y));
		float cloth = upright * smoothstep(0.16, 0.26, chroma) * smoothstep(0.5, 0.62, lum) * (1.0 - leafy);
		float cloth_warm = cloth * step(seen.b, seen.r);
		result = mix(result, mix(rust, rust * 0.7, 1.0 - smoothstep(0.3, 0.6, lum)), clamp(red + cloth_warm, 0.0, 1.0) * float(mode != 2));
		result = mix(result, mid_blue, cloth * (1.0 - step(seen.b, seen.r)) * float(mode != 2));
		// the sky is paper with a little blue let in at the top; the cloud sea below is pale blue and cream
		vec3 sky = mix(cream, pale_blue, clamp(1.0 - SCREEN_UV.y * 2.2, 0.0, 1.0) * 0.55);
		result = mix(result, sky, far);
		// patterns: only on cloth, on roofs and on the cloud sea; large; faded before they get small enough to shimmer
		float px_world = d * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);  // metres a pixel covers here
		float facing = clamp(abs(n.z), 0.0, 1.0);
		float roof = smoothstep(0.3, 0.4, abs(wn.y)) * (1.0 - smoothstep(0.7, 0.8, abs(wn.y))) * (1.0 - leafy);
		float clouds = step(0.8, wn.y) * step(world.y, -30.0);
		float cell = clouds > 0.5 ? 14.0 : (roof > 0.5 ? 1.5 : 1.1);
		float readable = smoothstep(14.0, 30.0, cell * facing / max(px_world, 0.0001));
		float motif = 0.0;
		if (clouds > 0.5) {
			motif = seigaiha(world.xz / cell);
		} else if (roof > 0.5) {
			motif = seigaiha((abs(wn.x) > abs(wn.z) ? anchored.zy : anchored.xy) / cell);
		} else if (cloth > 0.0) {
			motif = diamonds((abs(wn.x) > abs(wn.z) ? anchored.zy : anchored.xy) / cell);
		}
		float cut = motif * readable * clamp(clouds + roof + cloth, 0.0, 1.0) * (1.0 - far) * float(mode != 2);
		result = mix(result, mix(result, cream, 0.55), cut);  // the stencil lets some of the paper through, no more
		// the line: deep indigo, thin and not quite solid; on the deepest blue it turns light
		float dark_here = 1.0 - smoothstep(0.2, 0.34, lum);
		vec2 thread = FRAGCOORD.xy / (2.2 * s);
		result *= 0.965 + 0.035 * sin(thread.x * 3.14159) * sin(thread.y * 3.14159);
		result = mix(result, mix(deep, pale_blue, dark_here), edge * 0.8);
	} else if (tech == 2) {
		vec3 shade_tint = mix(ramp0, ramp0_from, old);
		vec3 sky_tint = mix(ramp3, ramp3_from, old);
		float far = smoothstep(500.0, 900.0, d);
		// the wash runs past the line: colour from a point nudged by slow noise, a few neighbours, softly
		vec2 q = FRAGCOORD.xy / (60.0 * s);
		vec2 run = (vec2(blot(q), blot(q + 17.0)) - 0.5) * 11.0 * s / VIEWPORT_SIZE;
		vec3 wash = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			wash += texture(screen_tex, SCREEN_UV + run + offs[i] * 3.0 * s / VIEWPORT_SIZE).rgb;
		}
		wash *= 0.25 * mix(tint, tint_from, old);
		float wl = pow(clamp(dot(wash, vec3(0.299, 0.587, 0.114)), 0.0, 1.0), 0.45);
		float shade = 1.0 - smoothstep(0.28, 0.52, wl);  // shade is a violet-grey wash, not darkness
		wash = mix(wash, shade_tint * (0.6 + 0.7 * wl), shade * 0.5);
		wash = mix(vec3(dot(wash, vec3(0.333))), wash, 1.25);
		// thinned towards the paper: most in the light and far away; pigment gathers unevenly
		float pool = blot(q * 0.6 + 3.0) * 0.75 + blot(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q * 1.3) * 0.25;
		float strength = mix(0.95, 0.5, smoothstep(0.6, 0.97, wl)) * (0.84 + 0.3 * pool);
		strength *= 1.0 - 0.5 * smoothstep(60.0, 400.0, d);
		vec3 painted = mix(sheet_colour, wash, clamp(strength, 0.0, 1.0));
		// the sky: bare paper with a little blue let in at the top
		vec3 sky = mix(sheet_colour, sky_tint, clamp((1.0 - SCREEN_UV.y * 1.7) * (0.35 + 0.9 * pool), 0.0, 1.0) * 0.75);
		result = mix(painted, sky, far);
		if (mode == 2) {  // the pen alone: paper, the line, a few strokes in the shade
			float stroke = step(fract((FRAGCOORD.x + FRAGCOORD.y * 0.6) / (6.0 * s)), 0.22) * shade * (1.0 - far);
			result = mix(sheet_colour, line, stroke * 0.5);
		}
		result *= 0.965 + 0.05 * hash(floor(FRAGCOORD.xy / max(s, 1.0)));  // the tooth of the paper
		float alive = 0.62 + 0.38 * smoothstep(0.2, 0.7, blot(FRAGCOORD.xy / (16.0 * s)));  // the pen presses and lifts
		result = mix(result, line, edge * alive);
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
