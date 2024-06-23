#version 460 core

layout (location = 0) in vec3  pos; 
layout (location = 1) in vec4  color;
layout (location = 2) in vec2  uv;
layout (location = 3) in uint texture;

out vec4  vertex_color;
out vec2  vertex_uv;
flat out uint vertex_texture;

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_projection;

void main() {
  gl_Position = u_projection * u_view * u_model * vec4(pos, 1.0); 

  vertex_color   = color;
  vertex_uv      = uv;
  vertex_texture = texture;
}