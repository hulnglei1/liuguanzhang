shader_type canvas_item;
render_mode unshaded;

// 描边光：让深色角色（张飞的墨甲、关羽的绿袍）在深绿棋盘上不至于糊成一团。
// 做法是在贴图外侧扩出一圈暖色轮廓，不改变原图颜色，因此不动美术资产。
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float outline_px = 5.0;     // 贴图像素单位（256px 贴图 → 屏幕约 1.4px）
uniform float strength : hint_range(0.0, 1.0) = 0.5;

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
