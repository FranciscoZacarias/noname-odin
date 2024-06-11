#version 330 core

layout (location = 0) out vec4 pixel_color;

in vec4  vertex_color;
in vec2  vertex_uv;
in float vertex_texture;

uniform sampler2D u_texture[8];
uniform int u_window_width;
uniform int u_window_height;

void main() {
  vec2 tex_coords = gl_FragCoord.xy / vec2(u_window_width, u_window_height);
  pixel_color = vertex_color * texture(u_texture[int(vertex_texture)], vertex_uv);
}