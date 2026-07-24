shader_type spatial;

uniform float brightness_divisor : hint_range(1.0, 10.0) = 2.0; 
uniform float emission_strength : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    float time_step = floor(TIME * 24.0);
    
    float static_noise = fract(sin(dot(UV, vec2(13.0, 78.0)) + time_step) * 43759.0);
    
    vec3 static_color = vec3(static_noise) / brightness_divisor;
    
    ALBEDO = static_color;
    EMISSION = static_color * emission_strength;
}