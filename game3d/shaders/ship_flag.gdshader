// The flag of «Попутчик» (ADR-0036): black cloth that waves, a ragged fly, and our own sign drawn from distances —
// an eight-pointed compass rose in a ring over two crossed bones. No skull: nobody else's emblem. Drawn in the
// transparent pass, opaque and writing depth, so no island's technique redraws it. Own work, CC0.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, blend_mix;

uniform vec3 cloth : source_color = vec3(0.063, 0.063, 0.063);
uniform vec3 bone : source_color = vec3(0.918, 0.886, 0.792);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// One of the two crossed bones: a shaft with two knobs at each end. Negative inside.
float bone_at(vec2 p, float turn) {
	float c = cos(turn);
	float s = sin(turn);
	vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
	float shaft = max(abs(q.x) - 0.42, abs(q.y) - 0.028);
	vec2 e = vec2(abs(q.x) - 0.42, abs(q.y) - 0.04);
	return min(shaft, length(e) - 0.05);
}

// A four-pointed star with points `reach` long along the axes. Negative inside.
float star4(vec2 p, float reach, float waist) {
	p = abs(p);
	if (p.y > p.x) {
		p = p.yx;
	}
	vec2 a = vec2(reach, 0.0);
	vec2 b = vec2(waist, waist);
	vec2 ab = b - a;
	return ((p.x - a.x) * ab.y - (p.y - a.y) * ab.x) / length(ab);
}

void vertex() {
	float fly = UV.x;  // 0 at the hoist, 1 at the free end
	VERTEX.z += sin(UV.x * 7.0 - TIME * 4.0) * 0.16 * fly + sin(UV.x * 3.0 + UV.y * 2.0 - TIME * 2.6) * 0.1 * fly;
	VERTEX.y += sin(UV.x * 5.0 - TIME * 3.0) * 0.04 * fly;
}

void fragment() {
	float ragged = noise(vec2(UV.y * 9.0, 3.0)) * 0.16 + noise(vec2(UV.y * 31.0, 7.0)) * 0.05;  // the torn fly
	if (UV.x > 1.0 - ragged) {
		discard;
	}
	if (noise(UV * vec2(14.0, 9.0)) > 0.86 && UV.x > 0.55) {
		discard;  // a few holes
	}
	vec2 p = (UV - vec2(0.44, 0.5)) * vec2(1.7, 1.0);  // the sign, undistorted on a 1.7 : 1 flag
	float sign_d = min(bone_at(p, 0.6), bone_at(p, -0.6));
	float ring = abs(length(p) - 0.27) - 0.014;
	float rose = min(star4(p, 0.3, 0.045), star4(mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * p, 0.19, 0.04));
	float hole = length(p) - 0.30;  // the bones pass behind the rose
	sign_d = min(max(sign_d, -hole), min(ring, rose));
	float worn = 0.75 + 0.25 * noise(UV * 40.0);  // a rubbed emblem
	float ink = (1.0 - smoothstep(-0.004, 0.004, sign_d)) * worn;
	ALBEDO = mix(cloth * (0.7 + 0.5 * noise(UV * 6.0)), bone, ink);
	ROUGHNESS = 0.95;
	BACKLIGHT = vec3(0.04);
	ALPHA = 1.0;
}
