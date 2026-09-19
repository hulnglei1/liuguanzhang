shader_type canvas_item;

uniform float speed : hint_range(0.5, 10.0) = 3.0;
uniform float amplitude : hint_range(0.0, 10.0) = 3.5;
uniform bool is_active = true;

void vertex() {
    if (is_active) {
        // UV.y is 1.0 at bottom (feet), 0.0 at top.
        // Clamp weight so bottom 15% (feet) has STRICT ZERO movement.
        float weight = clamp((1.0 - UV.y) - 0.15, 0.0, 1.0) / 0.85;
        // Smooth sine wave
        VERTEX.y -= sin(TIME * speed) * amplitude * weight;
    }
}
