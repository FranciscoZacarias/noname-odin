package odinner

import "core:fmt"
import "core:math"
import "core:mem"
import "core:mem/virtual"
import gl "vendor:OpenGL"

MAX_TRIANGLES :: 1024

VertexShaderSource: cstring = "" +
"#version 330 core\n" +
"layout (location = 0) in vec3 aPos;\n" +
"void main()\n" +
"{\n" +
"   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n" +
"}"

FragmentShaderSource: cstring = "" +
"#version 330 core\n" +
"out vec4 FragColor;\n" +
"void main()\n" +
"{\n" +
"   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n" +
"}\n" 

Vertex :: struct {
  position: Vec3f32,
  color: Vec4f32
}

Renderer :: struct {
  shader: u32,
  vao:    u32,
  vbo:    u32,

  arena:     virtual.Arena,
  allocator: mem.Allocator,

  triangles_data:   []Vertex,
  triangles_count:  u32,
  triangles_max:    u32
}

GlobalRenderer: Renderer

renderer_init :: proc() {
  result := &GlobalRenderer

  arena_init_err := virtual.arena_init_static(&result.arena)
  if arena_init_err != mem.Allocator_Error.None {
    fmt.printf("Error initializing renderer arena. Error: %v", arena_init_err)
    assert(false)
  }
  result.allocator       = virtual.arena_allocator(&result.arena)
  result.triangles_data  = make([]Vertex, MAX_TRIANGLES, result.allocator)
  result.triangles_max   = MAX_TRIANGLES
  result.triangles_count = 0

  success: i32
  
	vertex_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &VertexShaderSource, nil)
	gl.CompileShader(vertex_shader)
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
  
	shader_info_log: string
	if b32(success) == gl.FALSE {
		gl.GetShaderInfoLog(vertex_shader, 512, nil, raw_data(shader_info_log))
		fmt.printf("Error compiling vertex shader: %s", shader_info_log)
		assert(false)
	}

	fragment_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &FragmentShaderSource, nil)
	gl.CompileShader(fragment_shader)
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
	if b32(success) == gl.FALSE {
		gl.GetShaderInfoLog(fragment_shader, 512, nil, raw_data(shader_info_log))
		fmt.printf("Error compiling fragment shader: %s", shader_info_log)
		assert(false)
	}

	result.shader = gl.CreateProgram()
	gl.AttachShader(result.shader, vertex_shader)
	gl.AttachShader(result.shader, fragment_shader)
	gl.LinkProgram(result.shader)
	gl.GetShaderiv(result.shader, gl.LINK_STATUS, &success)
	if b32(success) == gl.FALSE {
		gl.GetShaderInfoLog(fragment_shader, 512, nil, raw_data(shader_info_log))
		fmt.printf("Error linking shader program: %s", shader_info_log)
		assert(false)
	}

	gl.DetachShader(result.shader, vertex_shader)
	gl.DeleteShader(vertex_shader)
	gl.DetachShader(result.shader, fragment_shader)
	gl.DeleteShader(fragment_shader)

  // VAO
  gl.GenVertexArrays(1, &result.vao)
  gl.BindVertexArray(result.vao)

  // VBO
  gl.GenBuffers(1, &result.vbo)
  gl.BindBuffer(gl.ARRAY_BUFFER, result.vbo)
  gl.BufferData(gl.ARRAY_BUFFER, int(result.triangles_max) * 3 * size_of(Vertex), nil, gl.DYNAMIC_DRAW)

  gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, position))
  gl.EnableVertexAttribArray(0)

  gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, color))
  gl.EnableVertexAttribArray(1)

  gl.BindVertexArray(0)
  gl.BindBuffer(gl.ARRAY_BUFFER, 0)
}

renderer_begin_frame :: proc() {
  gl.ClearColor(math.sin_f32(Time), math.sin_f32(Time), math.cos_f32(Time), 1.0)
  gl.Clear(gl.COLOR_BUFFER_BIT)
  gl.UseProgram(GlobalRenderer.shader)
}

renderer_end_frame :: proc() {
  gl.BindVertexArray(GlobalRenderer.vao)
  gl.DrawArrays(gl.TRIANGLES, 0, i32(GlobalRenderer.triangles_count) * 3)
  gl.BufferSubData(gl.ARRAY_BUFFER, 0, int(GlobalRenderer.triangles_count) * 3 * size_of(Vertex), raw_data(GlobalRenderer.triangles_data[:]))
  gl.UseProgram(0)
}

renderer_push_triangle :: proc(a_position: Vec3f32, a_color: Vec4f32, b_position: Vec3f32, b_color: Vec4f32, c_position: Vec3f32, c_color: Vec4f32) {
  if GlobalRenderer.triangles_count + 1 >= GlobalRenderer.triangles_max {
    fmt.println("Too many triangles. Time to consider a dynamic array...")
    assert(false)
  }

  index: u32 = GlobalRenderer.triangles_count * 3

  GlobalRenderer.triangles_data[index+0].position = a_position
  GlobalRenderer.triangles_data[index+0].color    = a_color

  GlobalRenderer.triangles_data[index+1].position = a_position
  GlobalRenderer.triangles_data[index+1].color    = a_color

  GlobalRenderer.triangles_data[index+2].position = a_position
  GlobalRenderer.triangles_data[index+2].color    = a_color

  GlobalRenderer.triangles_count += 1
}