#version 460 core

layout (location = 0) out vec4 pixel_color;

in vec4  vertex_color;
in vec2  vertex_uv;
flat in uint vertex_texture;

uniform sampler2D u_texture[8];

void main() {
  pixel_color = vertex_color * texture(u_texture[vertex_texture], vertex_uv);
}