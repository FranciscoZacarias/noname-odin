#version 460 core

layout (location = 0) out vec4 pixel_color;

in vec4  vertex_color;
in vec2  vertex_uv;
flat in uint vertex_texture;

uniform sampler2D u_texture[8];

void main() {
  // NOTE(fz): Some hardware does not handle runtime variable indexing (u_texture[vertex_texture]) properly.
  // My laptop was auto selecting the GPU and was picking the integrated graphics for my AMD processor and
  // it was overlapping textures with this solution, but a switch statement worked fine. By making the nvidia GPU by default, the issue is fixed.
  pixel_color = vertex_color * texture(u_texture[vertex_texture], vertex_uv);
}