package odinner

import "core:os"
import "core:fmt"
import "core:strings"

import gl "vendor:OpenGL"
import stb_img "vendor:stb/image"
import lm "core:math/linalg/glsl"

MAX_TRIANGLES :: 1024
MAX_VERTICES  :: MAX_TRIANGLES * 3
MAX_TEXTURES  :: 8

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

	vertices: [dynamic]Vertex,
	textures: [dynamic]u32,
}

GRenderer: Renderer

renderer_init :: proc () {
	shader_ids := [2]u32{}
	compile_shader_ok: bool

	vs_source, vs_success := os.read_entire_file("shader/default_vs.glsl")
	defer delete(vs_source)
	if !vs_success { 
		fmt.printf("Error reading default_vs.glsl\n")
		assert(false)
	}
	shader_ids[0], compile_shader_ok = gl.compile_shader_from_source(string(vs_source), gl.Shader_Type.VERTEX_SHADER)
	if !compile_shader_ok {
		assert(false)
	}

	fs_source, fs_success := os.read_entire_file("shader/default_fs.glsl")
	defer delete(fs_source)
	if !fs_success { 
		fmt.printf("Error reading default_vs.glsl\n")
		assert(false)
	}
	shader_ids[1], compile_shader_ok = gl.compile_shader_from_source(string(fs_source), gl.Shader_Type.FRAGMENT_SHADER)
	if !compile_shader_ok {
		assert(false)
	}

	shader_program, shader_program_ok := gl.create_and_link_program(shader_ids[:])
	if !shader_program_ok {
		assert(false)
	}
	GRenderer.shader = shader_program

	for shader in shader_ids {
		gl.DetachShader(shader_program, shader)
		gl.DeleteShader(shader)
	}

	// Default VAO
	{
		gl.GenVertexArrays(1, &GRenderer.vao)
		gl.BindVertexArray(GRenderer.vao)
	}

	// Default VBO
	{
		gl.GenBuffers(1, &GRenderer.vbo)
		gl.BindBuffer(gl.ARRAY_BUFFER, GRenderer.vbo)
		gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex) * MAX_VERTICES, nil, gl.DYNAMIC_DRAW)
	
		gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, position))
		gl.EnableVertexAttribArray(0)
		gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, color))
		gl.EnableVertexAttribArray(1)
		gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, uv))
		gl.EnableVertexAttribArray(2)
		gl.VertexAttribPointer(3, 1, gl.FLOAT, gl.FALSE, size_of(Vertex), offset_of(Vertex, texture))
		gl.EnableVertexAttribArray(3)
	}

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	gl.UseProgram(GRenderer.shader)
	{
		textures := [8]i32{ 0, 1, 2, 3, 4, 5, 6, 7 }
		renderer_set_uniform_i32v("u_texture", 8, raw_data(&textures))
	}
	gl.UseProgram(0)

	GRenderer.vertices = make([dynamic]Vertex, 0)
	reserve(&GRenderer.vertices, MAX_VERTICES)
	GRenderer.textures = make([dynamic]u32, 0)
	reserve(&GRenderer.textures, MAX_TEXTURES)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

renderer_texture_load :: proc (path: string) -> u32 {
	exists := os.exists(path)
	if !exists {
		fmt.printf("Texture '%v' doesn't exist.\n", path)
		assert(false)
	}

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

renderer_begin_frame :: proc () {
	gl.UseProgram(GRenderer.shader)

	gl.Clear(gl.COLOR_BUFFER_BIT)
  gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
  gl.Enable(gl.DEPTH_TEST)
}

renderer_end_frame :: proc () {
	gl.UseProgram(GRenderer.shader)

	model := lm.identity(lm.mat4)
	renderer_set_uniform_mat4fv("u_model",      &model) // TODO(fz): Temporary. Model should come from whatever we're rendering
	renderer_set_uniform_mat4fv("u_view",       &AppState.view)
	renderer_set_uniform_mat4fv("u_projection", &AppState.projection)
	
	for i: u32 = 0; i < u32(len(GRenderer.textures)); i += 1 {
		gl.ActiveTexture(gl.TEXTURE0 + i)
		gl.BindTexture(gl.TEXTURE_2D, GRenderer.textures[i])
	}

	gl.BindVertexArray(GRenderer.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, GRenderer.vbo)
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(GRenderer.vertices) * 3 * size_of(Vertex), raw_data(GRenderer.vertices[:]))

	gl.DrawArrays(gl.TRIANGLES, 0, i32(len(GRenderer.vertices)) * 3)
}

renderer_push_triangle :: proc (a_position: lm.vec3, a_uv: lm.vec2, a_color: lm.vec4,
																b_position: lm.vec3, b_uv: lm.vec2, b_color: lm.vec4,
																c_position: lm.vec3, c_uv: lm.vec2, c_color: lm.vec4,
																texture: u32) {
	texture_index: i32 = -1
	for i in 0..<len(GRenderer.textures) {
		if GRenderer.textures[i] == texture {
			texture_index = i32(i)
			break
		}
	}
	
	// TODO(fz): If we add more textures than MAX_TEXTURES, we still have to handle that.
	// TODO(fz): This should probably be in renderer_load_texture.
	// TODO(fz): Do we need to clean them up? Didn't implement it yet because I think now they are kept during the lifetime of the program
	total_textures := len(GRenderer.textures)
	if texture_index == -1 && total_textures < MAX_TEXTURES {
		append(&GRenderer.textures, texture)
		texture_index = i32(total_textures)
	}
	if total_textures >= MAX_TEXTURES {
		fmt.println("Max textures reached!\n")
		assert(false)
	}

	a := Vertex{ a_position, a_color, a_uv, texture_index }
	append(&GRenderer.vertices, a)
	b := Vertex{ b_position, b_color, b_uv, texture_index }
	append(&GRenderer.vertices, b)
	c := Vertex{ c_position, c_color, c_uv, texture_index }
	append(&GRenderer.vertices, c)
}

renderer_push_quad :: proc (quad: Quad, color: lm.vec4, texture: u32) {
	a := quad.point
	b := lm.vec3{quad.point.x + quad.width, quad.point.y, quad.point.z}
	c := lm.vec3{quad.point.x + quad.width, quad.point.y + quad.height, quad.point.z}
	d := lm.vec3{quad.point.x, quad.point.y + quad.height, quad.point.z}
	renderer_push_triangle(a, lm.vec2{0.0, 0.0}, color, b, lm.vec2{1.0, 0.0}, color, c, lm.vec2{1.0, 1.0}, color, texture)
	renderer_push_triangle(c, lm.vec2{1.0, 1.0}, color, d, lm.vec2{0.0, 1.0}, color, a, lm.vec2{0.0, 0.0}, color, texture)
}

renderer_update_window_dimensions :: proc (width: i32, height: i32) {
	gl.UseProgram(GRenderer.shader)
	renderer_set_uniform_i32("u_window_width", width)
	renderer_set_uniform_i32("u_window_height", height)
}

renderer_set_uniform_mat4fv :: proc (uniform: string, mat: ^lm.mat4) {
	uniform_location: i32 = gl.GetUniformLocation(GRenderer.shader, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to find Mat4fv Uniform :: mat4 '%v'\n", uniform)
		return
	}
	gl.UniformMatrix4fv(uniform_location, 1, false, raw_data(mat))
}

renderer_set_uniform_f32 :: proc (uniform: string, f: f32) {
	uniform_location: i32 = gl.GetUniformLocation(GRenderer.shader, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to find f32 Uniform :: float '%v'\n", uniform)
		return
	}
	gl.Uniform1f(uniform_location, f)
}

renderer_set_uniform_i32v :: proc (uniform: string, count: i32, i: ^i32) {
	uniform_location: i32 = gl.GetUniformLocation(GRenderer.shader, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to find [%v]i32 Uniform :: '%v'\n", count, uniform)
		return
	}
	gl.Uniform1iv(uniform_location, count, i)
}

renderer_set_uniform_i32 :: proc (uniform: string, i: i32) {
	uniform_location: i32 = gl.GetUniformLocation(GRenderer.shader, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to find i32 Uniform :: '%v'\n", uniform)
		return
	}
	gl.Uniform1i(uniform_location, i)
}