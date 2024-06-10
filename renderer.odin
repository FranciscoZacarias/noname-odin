package odinner

import "core:os"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:mem/virtual"
import gl "vendor:OpenGL"

MAX_TRIANGLES :: 1024
MAX_VERTICES  :: MAX_TRIANGLES * 3

Vertex :: struct {
  position: Vec3f32,
  color: Color
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
  arena_init_err := virtual.arena_init_static(&GlobalRenderer.arena)
  if arena_init_err != mem.Allocator_Error.None {
    fmt.printf("Error initializing renderer arena. Error: %v", arena_init_err)
    assert(false)
  }
  GlobalRenderer.allocator       = virtual.arena_allocator(&GlobalRenderer.arena)
  GlobalRenderer.triangles_data  = make([]Vertex, MAX_TRIANGLES, GlobalRenderer.allocator)
  GlobalRenderer.triangles_max   = MAX_TRIANGLES
  GlobalRenderer.triangles_count = 0

  vertex_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
  {
    vs_source, vs_success := os.read_entire_file("shader/vs.glsl")
    if !vs_success { 
      fmt.printf("Error reading vs.glsl\n")
      assert(false)
    }

    vs_data_copy  := cstring(raw_data(string(vs_source)))
    delete(vs_source)
    gl.ShaderSource(vertex_shader, 1, &vs_data_copy, nil)
    gl.CompileShader(vertex_shader)
    success: i32
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
      
    if b32(success) == gl.FALSE {
      shader_info_log: string
      gl.GetShaderInfoLog(vertex_shader, 512, nil, raw_data(shader_info_log))
      fmt.printf("Error compiling vertex shader: %s", shader_info_log)
      assert(false)
    }
  }

  fragment_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
  {
    fs_source, fs_success := os.read_entire_file("shader/fs.glsl")
    if !fs_success { 
      fmt.printf("Error reading vs.glsl\n")
      assert(false)
    }
    fs_data_copy  := cstring(raw_data(string(fs_source)))
    delete(fs_source)
    fragment_shader_source_path: cstring = "shader/fs.glsl"
    gl.ShaderSource(fragment_shader, 1, &fs_data_copy, nil)
    gl.CompileShader(fragment_shader)
    success: i32
    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
    if b32(success) == gl.FALSE {
      shader_info_log: string
      gl.GetShaderInfoLog(fragment_shader, 512, nil, raw_data(shader_info_log))
      fmt.printf("Error compiling fragment shader: %s", shader_info_log)
      assert(false)
    }
  }

	GlobalRenderer.shader = gl.CreateProgram()
	gl.AttachShader(GlobalRenderer.shader, vertex_shader)
	gl.AttachShader(GlobalRenderer.shader, fragment_shader)
	gl.LinkProgram(GlobalRenderer.shader)
  success: i32
	gl.GetProgramiv(GlobalRenderer.shader, gl.LINK_STATUS, &success)
	if b32(success) == gl.FALSE {
    shader_info_log: [512]u8
		gl.GetShaderInfoLog(fragment_shader, 512, nil, &shader_info_log[0])
		fmt.printf("Error linking shader program: '%s'", shader_info_log)
	}
  
	gl.DetachShader(GlobalRenderer.shader, vertex_shader)
	gl.DeleteShader(vertex_shader)
	gl.DetachShader(GlobalRenderer.shader, fragment_shader)
	gl.DeleteShader(fragment_shader)

  // VAO
  gl.GenVertexArrays(1, &GlobalRenderer.vao)
  gl.BindVertexArray(GlobalRenderer.vao)

  // VBO
  gl.GenBuffers(1, &GlobalRenderer.vbo)
  gl.BindBuffer(gl.ARRAY_BUFFER, GlobalRenderer.vbo)
  gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * MAX_VERTICES, nil, gl.DYNAMIC_DRAW)

  gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, position))
  gl.EnableVertexAttribArray(0)
  
  gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, color))
  gl.EnableVertexAttribArray(1)

  gl.BindBuffer(gl.ARRAY_BUFFER, 0)
  gl.BindVertexArray(0)

  gl.UseProgram(GlobalRenderer.shader)
}

renderer_begin_frame :: proc() {
  gl.Clear(gl.COLOR_BUFFER_BIT)
}

renderer_end_frame :: proc() {
  gl.UseProgram(GlobalRenderer.shader)

  gl.BindVertexArray(GlobalRenderer.vao)
  gl.BindBuffer(gl.ARRAY_BUFFER, GlobalRenderer.vbo)
  gl.BufferSubData(gl.ARRAY_BUFFER, 0, int(GlobalRenderer.triangles_count) * 3 * size_of(Vertex), raw_data(GlobalRenderer.triangles_data))

  gl.DrawArrays(gl.TRIANGLES, 0, i32(GlobalRenderer.triangles_count) * 3)
}

renderer_push_triangle :: proc(a_position: Vec3f32, a_color: Color, b_position: Vec3f32, b_color: Color, c_position: Vec3f32, c_color: Color) {
  if GlobalRenderer.triangles_count + 1 >= GlobalRenderer.triangles_max {
    fmt.println("Too many triangles. Time to consider a dynamic array...")
    assert(false)
  }

  index: u32 = GlobalRenderer.triangles_count * 3

  GlobalRenderer.triangles_data[index+0].position = a_position
  GlobalRenderer.triangles_data[index+0].color    = a_color

  GlobalRenderer.triangles_data[index+1].position = b_position
  GlobalRenderer.triangles_data[index+1].color    = b_color

  GlobalRenderer.triangles_data[index+2].position = c_position
  GlobalRenderer.triangles_data[index+2].color    = c_color

  GlobalRenderer.triangles_count += 1
}

renderer_push_quad :: proc(a_position: Vec3f32, a_color: Color, b_position: Vec3f32, b_color: Color, c_position: Vec3f32, c_color: Color, d_position: Vec3f32, d_color: Color) {
  renderer_push_triangle(a_position, a_color, b_position, b_color, c_position, c_color)
  renderer_push_triangle(c_position, c_color, d_position, d_color, a_position, a_color)
}