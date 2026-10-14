shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform sampler2D portal_texture : source_color, filter_linear_mipmap;
uniform vec4 portal_color : source_color = vec4(0.3, 0.5, 1.0, 1.0); // Adds color tuning
uniform float swirl_strength : hint_range(-10.0, 10.0) = 5.0;
uniform float rotation_speed : hint_range(-10.0, 10.0) = 2.0;
uniform float edge_softness : hint_range(0.01, 1.0) = 0.4; // Controls the edge glow fade

void fragment() {
    // Center the UV coordinates to [-0.5, 0.5]
    vec2 uv = UV - vec2(0.5);
    
    // Calculate distance from the center (0.0 at center, 0.5 at edges)
    float dist = length(uv);
    
    // Create an angle that changes over time and intensifies closer to the center
    float angle = (TIME * rotation_speed) + (1.0 / (dist + 0.1) * swirl_strength);
    
    // Rotate the UV coordinates
    vec2 rotated_uv;
    rotated_uv.x = uv.x * cos(angle) - uv.y * sin(angle);
    rotated_uv.y = uv.x * sin(angle) + uv.y * cos(angle);
    
    // Restore UV coordinates back to [0, 1] space
    rotated_uv += vec2(0.5);
    
    // Sample your texture using the twisted UVs
    vec4 tex_color = texture(portal_texture, rotated_uv);
    
    // Calculate a circular mask (fades out as dist approaches 0.5)
    float circle_mask = smoothstep(0.5, 0.5 - edge_softness, dist);
    
    // Apply colors and transparency
    ALBEDO = tex_color.rgb * portal_color.rgb;
    ALPHA = tex_color.a * portal_color.a * circle_mask;
}
