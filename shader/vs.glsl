#version 330 core

layout (location = 0) in vec3  pos; 
layout (location = 1) in vec4  color;
layout (location = 2) in vec2  uv;
layout (location = 3) in float texture;

out vec4  vertex_color;
out vec2  vertex_uv;
out float vertex_texture;

void main() {
  gl_Position = vec4(pos, 1.0); 

  vertex_color   = color;
  vertex_uv      = uv;
  vertex_texture = texture;
}