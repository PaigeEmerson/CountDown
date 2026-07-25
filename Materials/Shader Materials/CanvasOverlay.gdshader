shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec2 base_resolution = vec2(1920.0, 1080.0); 
uniform float pixel_size : hint_range(0.0, 20.0, 0.1);
uniform float levels : hint_range(0.0, 200.0, 1.0);
uniform vec2 gamma;

void fragment() {
    vec2 pixel_count = base_resolution / (max(pixel_size, 0.001) * 2.0);
    
    vec2 pixelated_uv = floor(SCREEN_UV * pixel_count) / pixel_count;
    vec4 color = texture(screen_texture, pixelated_uv);
    
    color.rgb = pow(color.rgb, vec3(gamma.x));
    
    float grayscale = max(color.r, max(color.g, color.b));
    float lower = floor(grayscale * levels) / levels;
    float higher = ceil(grayscale * levels) / levels;
    
    float lower_diff = abs(lower - grayscale);
    float higher_diff = abs(higher - grayscale);
    
    float level = lower_diff < higher_diff ? lower : higher;
    float adjustment = level / max(grayscale, 0.0001); 
    
    color.rgb *= adjustment;
    color.rgb = pow(color.rgb, vec3(gamma.y));
    
    COLOR.rgb = color.rgb; 
}