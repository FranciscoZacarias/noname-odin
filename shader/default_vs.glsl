#version 460 core

layout (location = 0) in vec3 pos; 
layout (location = 1) in vec4 color;
layout (location = 2) in vec3 uvw;
layout (location = 3) in vec3 normal;
layout (location = 4) in uint texture;

out vec4 vertex_color;
out vec3 vertex_uvw;
out vec3 vertex_normal;
flat out uint vertex_texture;

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_projection;

void main() {
  gl_Position = u_projection * u_view * u_model * vec4(pos, 1.0); 

  vertex_color   = color;
  vertex_uvw     = uvw;
  vertex_normal  = normal;
  vertex_texture = texture;
}