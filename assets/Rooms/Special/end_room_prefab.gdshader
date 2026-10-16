shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded; // Changed cull_back to cull_disabled

uniform sampler2D portal_texture : source_color, filter_linear_mipmap;
uniform vec4 portal_color : source_color = vec4(1.0, 0.9, 0.0, 1.0); 
// Boosts the color past 1.0 to trigger Godot's WorldEnvironment glow/bloom
uniform float emission_intensity : hint_range(1.0, 20.0) = 3.0; 
uniform float swirl_strength : hint_range(-10.0, 10.0) = 5.0;
uniform float rotation_speed : hint_range(-10.0, 10.0) = 2.0;
uniform float edge_softness : hint_range(0.01, 1.0) = 0.4; 

void fragment() {
    // Center the UV coordinates to [-0.5, 0.5]
    vec2 uv = UV - vec2(0.5);
    
    // Calculate distance from the center
    float dist = length(uv);
    
    // Create an angle that changes over time and intensifies closer to the center
    float angle = (TIME * rotation_speed) + (1.0 / (dist + 0.1) * swirl_strength);
    
    // Rotate the UV coordinates
    vec2 rotated_uv;
    rotated_uv.x = uv.x * cos(angle) - uv.y * sin(angle);
    rotated_uv.y = uv.x * sin(angle) + uv.y * cos(angle);
    
    // Restore UV coordinates back to space
    rotated_uv += vec2(0.5);
    
    // Sample the texture
    vec4 tex_color = texture(portal_texture, rotated_uv);
    
    // Convert texture to grayscale (luminance) so its native color doesn't clash
    float brightness = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Calculate a circular mask
    float circle_mask = smoothstep(0.5, 0.5 - edge_softness, dist);
    
    // Mix the base brightness with the color, then multiply by intensity for vibrancy
    ALBEDO = vec3(brightness) * portal_color.rgb * emission_intensity;
    ALPHA = tex_color.a * portal_color.a * circle_mask;
}
