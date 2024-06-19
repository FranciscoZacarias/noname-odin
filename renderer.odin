package odinner

import "core:os"
import "core:fmt"
import "core:strings"

import gl "vendor:OpenGL"
import stb_img "vendor:stb/image"
import lm "core:math/linalg/glsl"

MSAA_SAMPLES :: 4

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

	msaa_fbo: u32,
	msaa_rbo: u32,
	msaa_texture_color_buffer_multisampled: u32,

	post_processing_fbo: u32,

	screen_texture: u32,
	screen_shader: u32,
	screen_vao: u32,
	screen_vbo: u32,
}

GRenderer: Renderer

renderer_init :: proc (window_width: i32, window_height: i32) {

	// Default program
	{
		vs_source, vs_success := os.read_entire_file("shader/default_vs.glsl")
		defer delete(vs_source)
		if !vs_success { 
			fmt.printf("Error reading default_vs.glsl\n")
			assert(false)
		}
		vs_id, vs_ok := gl.compile_shader_from_source(string(vs_source), gl.Shader_Type.VERTEX_SHADER)
		if !vs_ok {
			assert(false)
		}

		fs_source, fs_success := os.read_entire_file("shader/default_fs.glsl")
		defer delete(fs_source)
		if !fs_success { 
			fmt.printf("Error reading default_fs.glsl\n")
			assert(false)
		}
		fs_id, fs_ok := gl.compile_shader_from_source(string(fs_source), gl.Shader_Type.FRAGMENT_SHADER)
		if !fs_ok {
			assert(false)
		}

		shader_program, shader_program_ok := gl.create_and_link_program([]u32{vs_id, fs_id})
		if !shader_program_ok {
			assert(false)
		}
		GRenderer.shader = shader_program

		gl.DetachShader(shader_program, vs_id)
		gl.DeleteShader(vs_id)
		gl.DetachShader(shader_program, fs_id)
		gl.DeleteShader(fs_id)
	}

	// Default shader 
	{
		// VAO
		gl.GenVertexArrays(1, &GRenderer.vao)
		gl.BindVertexArray(GRenderer.vao)

		// VBO
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

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
		gl.BindVertexArray(0)

		GRenderer.vertices = make([dynamic]Vertex, 0)
		reserve(&GRenderer.vertices, MAX_VERTICES)
		GRenderer.textures = make([dynamic]u32, 0)
		reserve(&GRenderer.textures, MAX_TEXTURES)
	}

	// MSAA
	{
		gl.GenFramebuffers(1, &GRenderer.msaa_fbo)
		gl.GenTextures(1, &GRenderer.msaa_texture_color_buffer_multisampled)
		gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, GRenderer.msaa_texture_color_buffer_multisampled)
		gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, MSAA_SAMPLES, gl.RGB, window_width, window_height, gl.TRUE)
		gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, 0)

		gl.GenRenderbuffers(1, &GRenderer.msaa_rbo)
		gl.BindRenderbuffer(gl.RENDERBUFFER, GRenderer.msaa_rbo)
		gl.RenderbufferStorageMultisample(gl.RENDERBUFFER, MSAA_SAMPLES, gl.DEPTH24_STENCIL8, window_width, window_height)
		gl.BindRenderbuffer(gl.RENDERBUFFER, 0)

		gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, GRenderer.msaa_fbo)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D_MULTISAMPLE, GRenderer.msaa_texture_color_buffer_multisampled, 0)
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, GRenderer.msaa_rbo)

		status: u32 = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
		if status != gl.FRAMEBUFFER_COMPLETE {
			fmt.printf("MSAA FBO is not complete. Status: %v\n", status)
			assert(false)
		}
	}

	// Post processing
	{
		gl.GenFramebuffers(1, &GRenderer.post_processing_fbo)
		gl.GenTextures(1, &GRenderer.screen_texture)
		gl.BindTexture(gl.TEXTURE_2D, GRenderer.screen_texture)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, window_width, window_height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

		gl.BindFramebuffer(gl.FRAMEBUFFER, GRenderer.post_processing_fbo)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, GRenderer.screen_texture, 0)

		status: u32 = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
		if status!= gl.FRAMEBUFFER_COMPLETE {
			fmt.printf("Post processing FBO is not complete. Status: %v\n", status)
			assert(false)
		}

		gl.BindTexture(gl.TEXTURE_2D, 0)
		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	}

	// Screen program
	{
		screen_vs_source, vs_success := os.read_entire_file("shader/screen_vs.glsl")
		defer delete(screen_vs_source)
		if !vs_success { 
			fmt.printf("Error reading screen_vs.glsl\n")
			assert(false)
		}
		vs_id, vs_ok := gl.compile_shader_from_source(string(screen_vs_source), gl.Shader_Type.VERTEX_SHADER)
		if !vs_ok {
			assert(false)
		}

		screen_fs_source, fs_success := os.read_entire_file("shader/screen_fs.glsl")
		defer delete(screen_fs_source)
		if !fs_success { 
			fmt.printf("Error reading screen_fs.glsl\n")
			assert(false)
		}
		fs_id, fs_ok := gl.compile_shader_from_source(string(screen_fs_source), gl.Shader_Type.FRAGMENT_SHADER)
		if !fs_ok {
			assert(false)
		}

		screen_shader, screen_shader_ok := gl.create_and_link_program([]u32{vs_id, fs_id})
		if !screen_shader_ok {
			assert(false)
		}
		GRenderer.screen_shader = screen_shader

		gl.DetachShader(screen_shader, vs_id)
		gl.DeleteShader(vs_id)
		gl.DetachShader(screen_shader, fs_id)
		gl.DeleteShader(fs_id)
	}

	// Screen shader
	{
		screen_vertices := [12]f32 {
			-1.0, 1.0,
			-1.0,-1.0,
			 1.0,-1.0,
			-1.0, 1.0,
			 1.0,-1.0,
			 1.0, 1.0,
		}
		
		// Screen VAO
		gl.GenVertexArrays(1, &GRenderer.screen_vao)
		gl.BindVertexArray(GRenderer.screen_vao)

		// Screen VBO
		gl.GenBuffers(1, &GRenderer.screen_vbo)
		gl.BindBuffer(gl.ARRAY_BUFFER, GRenderer.screen_vbo)
		gl.BufferData(gl.ARRAY_BUFFER, size_of(screen_vertices), &screen_vertices, gl.STATIC_DRAW)

		gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2*size_of(f32), 0)
		gl.EnableVertexAttribArray(0)

		gl.BindVertexArray(0)
		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	}

	// Set texture ids
	gl.UseProgram(GRenderer.shader)
	textures_ids := [8]i32{ 0, 1, 2, 3, 4, 5, 6, 7 }
	renderer_set_uniform_i32v(GRenderer.shader, "u_texture", 8, raw_data(&textures_ids))
	gl.UseProgram(0)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

renderer_on_resize :: proc(window_width: i32, window_height: i32) {
	// Rebuild MSAA buffers
	{
		gl.BindFramebuffer(gl.FRAMEBUFFER, GRenderer.msaa_fbo)
		gl.DeleteTextures(1, &GRenderer.msaa_texture_color_buffer_multisampled)
		gl.DeleteRenderbuffers(1, &GRenderer.msaa_rbo)
		gl.DeleteFramebuffers(1, &GRenderer.msaa_fbo);

		gl.GenFramebuffers(1, &GRenderer.msaa_fbo)
		gl.GenTextures(1, &GRenderer.msaa_texture_color_buffer_multisampled)
		gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, GRenderer.msaa_texture_color_buffer_multisampled)
		gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, MSAA_SAMPLES, gl.RGB, window_width, window_height, gl.TRUE)
		gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, 0)

		gl.GenRenderbuffers(1, &GRenderer.msaa_rbo)
		gl.BindRenderbuffer(gl.RENDERBUFFER, GRenderer.msaa_rbo)
		gl.RenderbufferStorageMultisample(gl.RENDERBUFFER, MSAA_SAMPLES, gl.DEPTH24_STENCIL8, window_width, window_height)
		gl.BindRenderbuffer(gl.RENDERBUFFER, 0)

		gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, GRenderer.msaa_fbo)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D_MULTISAMPLE, GRenderer.msaa_texture_color_buffer_multisampled, 0)
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, GRenderer.msaa_rbo)

		status: u32 = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
		if status != gl.FRAMEBUFFER_COMPLETE {
			fmt.printf("MSAA FBO is not complete. Status: %v\n", status)
			assert(false)
		}
	}

	// Rebuild Post processing and screen buffers
	{
		gl.GenFramebuffers(1, &GRenderer.post_processing_fbo)
		gl.GenTextures(1, &GRenderer.screen_texture)
		gl.BindTexture(gl.TEXTURE_2D, GRenderer.screen_texture)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, window_width, window_height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

		gl.BindFramebuffer(gl.FRAMEBUFFER, GRenderer.post_processing_fbo)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, GRenderer.screen_texture, 0)

		status: u32 = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
		if status!= gl.FRAMEBUFFER_COMPLETE {
			fmt.printf("Post processing FBO is not complete. Status: %v\n", status)
			assert(false)
		}

		gl.BindTexture(gl.TEXTURE_2D, 0)
		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	}
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
		gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, width, height, gl.RGB,  gl.UNSIGNED_BYTE, data)
	} else if (channels == 4) {
		gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, data)
	}

	return id
}

renderer_begin_frame :: proc () {
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, GRenderer.msaa_fbo)

	gl.ClearColor(0.0, 0.0, 0.0, 1.0)
  gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
  gl.Enable(gl.DEPTH_TEST)
}

renderer_end_frame :: proc (view: lm.mat4, projection: lm.mat4, window_width: i32, window_height: i32) {
	gl.UseProgram(GRenderer.shader)
	model      := lm.identity(lm.mat4)
	view       := view
	projection := projection
	renderer_set_uniform_mat4fv(GRenderer.shader, "u_model",      &model) // TODO(fz): Temporary. Model should come from whatever we're rendering
	renderer_set_uniform_mat4fv(GRenderer.shader, "u_view",       &view)
	renderer_set_uniform_mat4fv(GRenderer.shader, "u_projection", &projection)
	
	for i: u32 = 0; i < u32(len(GRenderer.textures)); i += 1 {
		gl.ActiveTexture(gl.TEXTURE0 + i)
		gl.BindTexture(gl.TEXTURE_2D, GRenderer.textures[i])
	}

	// Draw to MSAA FBO
	gl.BindVertexArray(GRenderer.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, GRenderer.vbo)
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(GRenderer.vertices) * 3 * size_of(Vertex), raw_data(GRenderer.vertices[:]))
	gl.DrawArrays(gl.TRIANGLES, 0, i32(len(GRenderer.vertices)) * 3)

	// Copy from MSAA FBO to Post Processing FBO
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, GRenderer.msaa_fbo)
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, GRenderer.post_processing_fbo)
	gl.BlitFramebuffer(0, 0, window_width, window_height, 0, 0, window_width, window_height, gl.COLOR_BUFFER_BIT, gl.NEAREST)

	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0)
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)
	
	gl.ClearColor(1.0, 1.0, 1.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.Disable(gl.DEPTH_TEST)

	gl.UseProgram(GRenderer.screen_shader)
	gl.BindVertexArray(GRenderer.screen_vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, GRenderer.screen_texture)
	fmt.printf("u_window_width: %v\n", window_width)
	fmt.printf("u_window_height: %v\n", window_height)
	renderer_set_uniform_i32(GRenderer.screen_shader, "u_window_width", window_width)
	renderer_set_uniform_i32(GRenderer.screen_shader, "u_window_height", window_height)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	gl.UseProgram(0)
	gl.BindVertexArray(0)
	gl.BindTexture(gl.TEXTURE_2D, 0)
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
	
}

renderer_set_uniform_mat4fv :: proc (program: u32, uniform: string, mat: ^lm.mat4) {
	uniform_location: i32 = gl.GetUniformLocation(program, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to find Mat4fv Uniform :: mat4 '%v'\n", uniform)
		return
	}
	gl.UniformMatrix4fv(uniform_location, 1, false, raw_data(mat))
}

renderer_set_uniform_f32 :: proc (program: u32, uniform: string, f: f32) {
	uniform_location: i32 = gl.GetUniformLocation(program, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to find f32 Uniform :: float '%v'\n", uniform)
		return
	}
	gl.Uniform1f(uniform_location, f)
}

renderer_set_uniform_i32v :: proc (program: u32, uniform: string, count: i32, i: ^i32) {
	uniform_location: i32 = gl.GetUniformLocation(program, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to find [%v]i32 Uniform :: '%v'\n", count, uniform)
		return
	}
	gl.Uniform1iv(uniform_location, count, i)
}

renderer_set_uniform_i32 :: proc (program: u32, uniform: string, i: i32) {
	uniform_location: i32 = gl.GetUniformLocation(program, strings.clone_to_cstring(uniform))
	if uniform_location == -1 {
		fmt.printf("Unable to find i32 Uniform :: '%v'\n", uniform)
		return
	}
	gl.Uniform1i(uniform_location, i)
}