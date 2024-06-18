#version 460 core

out vec4 FragColor;

uniform sampler2D screen_texture;
uniform int u_window_width;
uniform int u_window_height;

void main() {
  vec2 tex_coords = gl_FragCoord.xy / vec2(u_window_width, u_window_height);
  FragColor = texture(screen_texture, tex_coords);
}