shader_type canvas_item;
// Used for hit flashes and attack telegraphs (enemy.gd / player.gd set flash_amount).
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash_amount * COLOR.a);
}
