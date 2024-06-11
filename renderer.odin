package odinner

import "core:os"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import gl "vendor:OpenGL"
import stb_img "vendor:stb/image"
import lm "core:math/linalg/glsl"

MAX_TRIANGLES :: 1024
MAX_VERTICES  :: MAX_TRIANGLES * 3
MAX_TEXTURES  :: 8

Transform :: struct {
	scale:    lm.vec3,
	rotation: lm.quat,
	position: lm.vec3
}

Quad :: struct {
	point:  lm.vec3, // bottom left point
	width:  f32,
	height: f32,
}

Vertex :: struct {
	position: lm.vec3,
	color:    lm.vec4,
	uv:       lm.vec2,
	texture:  i32
}

Renderer :: struct {
	shader: u32,
	vao:    u32,
	vbo:    u32,

	triangles_data:   [MAX_VERTICES]Vertex,
	triangles_count:  u32,

	textures_data:    [MAX_TEXTURES]u32,
	textures_count:   u32
}

GlobalRenderer: Renderer

renderer_init :: proc() {
	GlobalRenderer.triangles_count = 0

	vertex_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	{
		vs_source, vs_success := os.read_entire_file("shader/vs.glsl")
		defer delete(vs_source)
		if !vs_success { 
			fmt.printf("Error reading vs.glsl\n")
			assert(false)
		}

		vs_data_copy := cstring(raw_data(string(vs_source)))
		gl.ShaderSource(vertex_shader, 1, &vs_data_copy, nil)
		gl.CompileShader(vertex_shader)
		success: i32
		gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
			
		if b32(success) == gl.FALSE {
			shader_info_log: [512]u8
			gl.GetShaderInfoLog(vertex_shader, 512, nil, raw_data(shader_info_log[:]))
			fmt.printf("Error compiling vertex shader: %s", shader_info_log)
			assert(false)
		}
	}

	fragment_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	{
		fs_source, fs_success := os.read_entire_file("shader/fs.glsl")
		defer delete(fs_source)
		if !fs_success { 
			fmt.printf("Error reading vs.glsl\n")
			assert(false)
		}
		fs_data_copy := cstring(raw_data(string(fs_source)))
		fragment_shader_source_path: cstring = "shader/fs.glsl"
		gl.ShaderSource(fragment_shader, 1, &fs_data_copy, nil)
		gl.CompileShader(fragment_shader)
		success: i32
		gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
		if b32(success) == gl.FALSE {
			shader_info_log: [512]u8
			gl.GetShaderInfoLog(fragment_shader, 512, nil, &shader_info_log[0])
			fmt.printf("Error compiling fragment shader: %s", shader_info_log)
			assert(false)
		}
	}

	GlobalRenderer.shader = gl.CreateProgram()
	{
		gl.AttachShader(GlobalRenderer.shader, vertex_shader)
		gl.AttachShader(GlobalRenderer.shader, fragment_shader)
		gl.LinkProgram(GlobalRenderer.shader)
		success: i32
		gl.GetProgramiv(GlobalRenderer.shader, gl.LINK_STATUS, &success)
		if b32(success) == gl.FALSE {
			shader_info_log: [512]u8
			gl.GetShaderInfoLog(fragment_shader, 512, nil, raw_data(shader_info_log[:]))
			fmt.printf("Error linking shader program: '%s'", shader_info_log)
		}
		gl.DetachShader(GlobalRenderer.shader, vertex_shader)
		gl.DeleteShader(vertex_shader)
		gl.DetachShader(GlobalRenderer.shader, fragment_shader)
		gl.DeleteShader(fragment_shader)
	}

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

	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, uv))
	gl.EnableVertexAttribArray(2)

	gl.VertexAttribPointer(3, 1, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, texture))
	gl.EnableVertexAttribArray(3)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	textures := [8]i32{ 0, 1, 2, 3, 4, 5, 6, 7 }
	renderer_set_uniform_i32v(GlobalRenderer.shader, "u_texture", 8, raw_data(&textures))

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

renderer_texture_load :: proc(path: string) -> u32 {
	width, height, channels: i32
	stb_img.set_flip_vertically_on_load(1)
	data := stb_img.load(strings.clone_to_cstring(path), &width, &height, &channels, 0)
	defer stb_img.image_free(data)

	id: u32
	gl.GenTextures(1, &id)    
	gl.BindTexture(gl.TEXTURE_2D, id)

	if channels == 3 {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB8, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	} else  if (channels == 4) {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	} else {
		fmt.printf("Error :: Unexpected number of channels when loading a texture.\n")
		assert(false)
	}
	
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	
	if (channels == 3) {
		gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, width, height, gl.RGB, gl.UNSIGNED_BYTE, data)
	} else if (channels == 4) {
		gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, data)
	}
	
	return id
}

renderer_begin_frame :: proc() {
	gl.Clear(gl.COLOR_BUFFER_BIT)
	GlobalRenderer.triangles_count = 0
}

renderer_end_frame :: proc() {
	for i: u32 = 0; i < MAX_TEXTURES; i += 1 {
		gl.ActiveTexture(gl.TEXTURE0 + i)
		gl.BindTexture(gl.TEXTURE_2D, GlobalRenderer.textures_data[i])
	}

	gl.UseProgram(GlobalRenderer.shader)
	gl.BindVertexArray(GlobalRenderer.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, GlobalRenderer.vbo)
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, int(GlobalRenderer.triangles_count) * 3 * size_of(Vertex), raw_data(GlobalRenderer.triangles_data[:]))

	gl.DrawArrays(gl.TRIANGLES, 0, i32(GlobalRenderer.triangles_count) * 3)
}

renderer_push_triangle :: proc( a_position: lm.vec3, a_uv: lm.vec2, a_color: lm.vec4,
																b_position: lm.vec3, b_uv: lm.vec2, b_color: lm.vec4,
																c_position: lm.vec3, c_uv: lm.vec2, c_color: lm.vec4,
																texture: u32) {
	texture_index: i32 = -1
	for i in 0..<GlobalRenderer.textures_count {
		if GlobalRenderer.textures_data[i] == texture {
			texture_index = i32(i)
			break
		}
	}
	
	// TODO(fz): If we add more textures than MAX_TEXTURES, we still have to handle that.
	// TODO(fz): This should probably be in renderer_load_texture.
	// TODO(fz): Do we need to clean them up? Didn't implement it yet because I think now they are kept during the lifetime of the program
	if texture_index == -1 && GlobalRenderer.textures_count < MAX_TEXTURES {
		GlobalRenderer.textures_data[GlobalRenderer.textures_count] = texture
		texture_index = i32(GlobalRenderer.textures_count)
		GlobalRenderer.textures_count += 1
	}

	index: u32 = GlobalRenderer.triangles_count * 3

	GlobalRenderer.triangles_data[index+0].position = a_position
	GlobalRenderer.triangles_data[index+0].color    = a_color
	GlobalRenderer.triangles_data[index+0].uv       = a_uv
	GlobalRenderer.triangles_data[index+0].texture  = texture_index

	GlobalRenderer.triangles_data[index+1].position = b_position
	GlobalRenderer.triangles_data[index+1].color    = b_color
	GlobalRenderer.triangles_data[index+1].uv       = b_uv
	GlobalRenderer.triangles_data[index+1].texture  = texture_index

	GlobalRenderer.triangles_data[index+2].position = c_position
	GlobalRenderer.triangles_data[index+2].color    = c_color
	GlobalRenderer.triangles_data[index+2].uv       = c_uv
	GlobalRenderer.triangles_data[index+2].texture  = texture_index

	GlobalRenderer.triangles_count += 1
}

renderer_push_quad :: proc(quad: Quad, color: lm.vec4, texture: u32) {
	a := quad.point
	b := lm.vec3{quad.point.x + quad.width, quad.point.y, quad.point.z}
	c := lm.vec3{quad.point.x + quad.width, quad.point.y + quad.height, quad.point.z}
	d := lm.vec3{quad.point.x, quad.point.y + quad.height, quad.point.z}
	renderer_push_triangle(a, lm.vec2{0.0, 0.0}, color, b, lm.vec2{1.0, 0.0}, color, c, lm.vec2{1.0, 1.0}, color, texture)
	renderer_push_triangle(c, lm.vec2{1.0, 1.0}, color, d, lm.vec2{0.0, 1.0}, color, a, lm.vec2{0.0, 0.0}, color, texture)
}


renderer_set_uniform_mat4fv :: proc (shader: u32, uniform: string, mat: ^lm.mat4) {
	uniform_location: i32 = gl.GetUniformLocation(shader, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to set Mat4fv Uniform :: %v not found\n", uniform)
		return
	}
	gl.UniformMatrix4fv(uniform_location, 1, false, raw_data(mat))
}

renderer_set_uniform_f32 :: proc(shader: u32, uniform: string, f: f32) {
	uniform_location: i32 = gl.GetUniformLocation(shader, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to set f32 Uniform :: %v not found\n", uniform)
		return
	}
	gl.Uniform1f(uniform_location, f)
}

renderer_set_uniform_i32v :: proc(shader: u32, uniform: string, count: i32, i: ^i32) {
	uniform_location: i32 = gl.GetUniformLocation(shader, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to set [%v]i32 Uniform :: %v not found\n", count, uniform)
		return
	}
	gl.Uniform1iv(uniform_location, count, i)
}