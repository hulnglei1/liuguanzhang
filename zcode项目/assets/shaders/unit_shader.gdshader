shader_type canvas_item;
render_mode unshaded;

// 单位外观一体化 shader：描边光（fragment）+ 锁脚呼吸（vertex）。
// 为什么合成一个：一个 CanvasItem 只能挂一个 material，之前描边占了坑，
// 呼吸就没地方挂了（demo 里的 shader_breathing 一直没合进来）。

// ---- 描边 ----
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float outline_px = 5.0;
uniform float strength : hint_range(0.0, 1.0) = 0.5;

// ---- 呼吸（锁脚：脚底 15% 严格不动）----
uniform bool breath_active = false;
uniform float breath_speed : hint_range(0.0, 8.0) = 2.0;
uniform float breath_amp : hint_range(0.0, 40.0) = 4.0;

void vertex() {
	if (breath_active) {
		// UV.y：1.0 在底部（脚），0.0 在顶部
		float weight = clamp((1.0 - UV.y) - 0.15, 0.0, 1.0) / 0.85;
		VERTEX.y -= sin(TIME * breath_speed) * breath_amp * weight;
	}
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 o = TEXTURE_PIXEL_SIZE * outline_px;

	float m = 0.0;
	m = max(m, texture(TEXTURE, UV + vec2(o.x, 0.0)).a);
	m = max(m, texture(TEXTURE, UV - vec2(o.x, 0.0)).a);
	m = max(m, texture(TEXTURE, UV + vec2(0.0, o.y)).a);
	m = max(m, texture(TEXTURE, UV - vec2(0.0, o.y)).a);
	m = max(m, texture(TEXTURE, UV + o * 0.7).a);
	m = max(m, texture(TEXTURE, UV - o * 0.7).a);

	float edge = clamp(m - tex.a, 0.0, 1.0) * strength;
	float inside = step(0.02, tex.a);
	vec3 rgb = mix(rim_color.rgb, tex.rgb, inside);
	COLOR = vec4(rgb, max(tex.a, edge));
}
