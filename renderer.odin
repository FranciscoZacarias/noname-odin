package odinner

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"

import gl "vendor:OpenGL"
import stb_img "vendor:stb/image"
import lm "core:math/linalg/glsl"

MSAA_SAMPLES :: 8

Initial_Vertices :: 8196
Initial_Lines    :: 8196
Initial_Indices  :: 8196
Initial_Textures :: 8

Quad :: struct {
	point:  lm.vec3, // bottom left point
	width:  f32,
	height: f32,
}

Vertex :: struct {
	position: lm.vec3,
	color:    lm.vec4,
	uvw:      lm.vec3,
	normal:   lm.vec3,
	texture:  u32,
}

Renderer :: struct {
	shader: u32,

	triangles_vao: u32,
	triangles_vbo: u32,
	triangles_ebo: u32,
	triangles_vertices: [dynamic]Vertex,
	triangles_indices:  [dynamic]u32,
	
	lines_vao: u32,
	lines_vbo: u32,
	lines_vertices: [dynamic]Vertex,

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

AppRenderer: Renderer

renderer_init :: proc (window_width: i32, window_height: i32) {
	if (false) {
		// DEBUG Info.
		renderer:= gl.GetString(gl.RENDERER)
		vendor:= gl.GetString(gl.VENDOR)
		version:= gl.GetString(gl.VERSION)
		glsl_version:= gl.GetString(gl.SHADING_LANGUAGE_VERSION)
		fmt.printf("Renderer: %s\n", renderer)
		fmt.printf("Vendor: %s\n", vendor)
		fmt.printf("OpenGL Version: %s\n", version)
		fmt.printf("GLSL Version: %s\n", glsl_version)
		max_texture_units: i32
		gl.GetIntegerv(gl.MAX_TEXTURE_IMAGE_UNITS, &max_texture_units)
		fmt.printf("Maximum Texture Image Units: %d\n", max_texture_units)
	}

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
		AppRenderer.shader = shader_program

		gl.DetachShader(shader_program, vs_id)
		gl.DeleteShader(vs_id)
		gl.DetachShader(shader_program, fs_id)
		gl.DeleteShader(fs_id)
	}

	// Default shader 
	{
		// [] - TODO(fz): Eventhough the vertex arrays are dynamic, the opengl buffers for each vertex will not reallocate. If the arrays reallocate, the buffers will not have space anymore.
		
		// Triangles
		{
			gl.CreateVertexArrays(1, &AppRenderer.triangles_vao)

			gl.EnableVertexArrayAttrib( AppRenderer.triangles_vao, 0)
			gl.VertexArrayAttribFormat( AppRenderer.triangles_vao, 0, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, position)))
			gl.VertexArrayAttribBinding(AppRenderer.triangles_vao, 0, 0)

			gl.EnableVertexArrayAttrib( AppRenderer.triangles_vao, 1)
			gl.VertexArrayAttribFormat( AppRenderer.triangles_vao, 1, 4, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, color)))
			gl.VertexArrayAttribBinding(AppRenderer.triangles_vao, 1, 0)

			gl.EnableVertexArrayAttrib( AppRenderer.triangles_vao, 2)
			gl.VertexArrayAttribFormat( AppRenderer.triangles_vao, 2, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, uvw)))
			gl.VertexArrayAttribBinding(AppRenderer.triangles_vao, 2, 0)
			
			gl.EnableVertexArrayAttrib( AppRenderer.triangles_vao, 3)
			gl.VertexArrayAttribFormat( AppRenderer.triangles_vao, 3, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, normal)))
			gl.VertexArrayAttribBinding(AppRenderer.triangles_vao, 3, 0)

			gl.EnableVertexArrayAttrib( AppRenderer.triangles_vao, 4)
			gl.VertexArrayAttribIFormat(AppRenderer.triangles_vao, 4, 1, gl.UNSIGNED_INT, u32(offset_of(Vertex, texture)))
			gl.VertexArrayAttribBinding(AppRenderer.triangles_vao, 4, 0)

			// VBO - Triangles
			gl.CreateBuffers(1, &AppRenderer.triangles_vbo)
			gl.NamedBufferData(AppRenderer.triangles_vbo, size_of(Vertex) * 3 * Initial_Vertices, nil, gl.DYNAMIC_DRAW)
			gl.VertexArrayVertexBuffer(AppRenderer.triangles_vao, 0, AppRenderer.triangles_vbo, 0, size_of(Vertex))

			// EBO - Triangles
			gl.CreateBuffers(1, &AppRenderer.triangles_ebo)
			gl.NamedBufferData(AppRenderer.triangles_ebo, size_of(u32) * Initial_Indices, nil, gl.STATIC_DRAW)
			gl.VertexArrayElementBuffer(AppRenderer.triangles_vao, AppRenderer.triangles_ebo)
		}

		// Lines
		{
			gl.CreateVertexArrays(1, &AppRenderer.lines_vao)

			gl.EnableVertexArrayAttrib( AppRenderer.lines_vao, 0)
			gl.VertexArrayAttribFormat( AppRenderer.lines_vao, 0, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, position)))
			gl.VertexArrayAttribBinding(AppRenderer.lines_vao, 0, 0)

			gl.EnableVertexArrayAttrib( AppRenderer.lines_vao, 1)
			gl.VertexArrayAttribFormat( AppRenderer.lines_vao, 1, 4, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, color)))
			gl.VertexArrayAttribBinding(AppRenderer.lines_vao, 1, 0)

			gl.EnableVertexArrayAttrib( AppRenderer.lines_vao, 2)
			gl.VertexArrayAttribFormat( AppRenderer.lines_vao, 2, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, uvw)))
			gl.VertexArrayAttribBinding(AppRenderer.lines_vao, 2, 0)

			gl.EnableVertexArrayAttrib( AppRenderer.lines_vao, 3)
			gl.VertexArrayAttribFormat( AppRenderer.lines_vao, 3, 3, gl.FLOAT, gl.FALSE, u32(offset_of(Vertex, normal)))
			gl.VertexArrayAttribBinding(AppRenderer.lines_vao, 3, 0)

			gl.EnableVertexArrayAttrib( AppRenderer.lines_vao, 4)
			gl.VertexArrayAttribIFormat(AppRenderer.lines_vao, 4, 1, gl.UNSIGNED_INT, u32(offset_of(Vertex, texture)))
			gl.VertexArrayAttribBinding(AppRenderer.lines_vao, 4, 0)

			// VBO - Lines
			gl.CreateBuffers(1, &AppRenderer.lines_vbo)
			gl.NamedBufferData(AppRenderer.lines_vbo, size_of(Vertex) * Initial_Lines, nil, gl.DYNAMIC_DRAW)
			gl.VertexArrayVertexBuffer(AppRenderer.lines_vao, 0, AppRenderer.lines_vbo, 0, size_of(Vertex))
		}
	}

	AppRenderer.triangles_vertices = make([dynamic]Vertex, 0)
	reserve(&AppRenderer.triangles_vertices, Initial_Vertices)
	AppRenderer.triangles_indices = make([dynamic]u32, 0)
	reserve(&AppRenderer.triangles_indices, Initial_Indices)
	AppRenderer.lines_vertices = make([dynamic]Vertex, 0)
	reserve(&AppRenderer.lines_vertices, Initial_Lines)
	AppRenderer.textures = make([dynamic]u32, 0)
	reserve(&AppRenderer.textures, Initial_Textures)

	// MSAA
	{
		gl.GenFramebuffers(1, &AppRenderer.msaa_fbo)
		gl.GenTextures(1, &AppRenderer.msaa_texture_color_buffer_multisampled)
		gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, AppRenderer.msaa_texture_color_buffer_multisampled)
		gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, MSAA_SAMPLES, gl.RGB, window_width, window_height, gl.TRUE)
		gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, 0)

		gl.GenRenderbuffers(1, &AppRenderer.msaa_rbo)
		gl.BindRenderbuffer(gl.RENDERBUFFER, AppRenderer.msaa_rbo)
		gl.RenderbufferStorageMultisample(gl.RENDERBUFFER, MSAA_SAMPLES, gl.DEPTH24_STENCIL8, window_width, window_height)
		gl.BindRenderbuffer(gl.RENDERBUFFER, 0)

		gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, AppRenderer.msaa_fbo)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D_MULTISAMPLE, AppRenderer.msaa_texture_color_buffer_multisampled, 0)
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, AppRenderer.msaa_rbo)

		status: u32 = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
		if status != gl.FRAMEBUFFER_COMPLETE {
			fmt.printf("MSAA FBO is not complete. Status: %v\n", status)
			assert(false)
		}
	}

	// Post processing
	{
		gl.GenFramebuffers(1, &AppRenderer.post_processing_fbo)
		gl.GenTextures(1, &AppRenderer.screen_texture)
		gl.BindTexture(gl.TEXTURE_2D, AppRenderer.screen_texture)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, window_width, window_height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

		gl.BindFramebuffer(gl.FRAMEBUFFER, AppRenderer.post_processing_fbo)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, AppRenderer.screen_texture, 0)

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
		AppRenderer.screen_shader = screen_shader

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
		gl.CreateVertexArrays(1, &AppRenderer.screen_vao)
		
		gl.EnableVertexArrayAttrib(AppRenderer.screen_vao, 0)
		gl.VertexArrayAttribFormat(AppRenderer.screen_vao, 0, 2, gl.FLOAT, gl.FALSE, 0)
		gl.VertexArrayAttribBinding(AppRenderer.screen_vao, 0, 0)
		
		// Screen VBO
		gl.CreateBuffers(1, &AppRenderer.screen_vbo)
		gl.NamedBufferData(AppRenderer.screen_vbo, size_of(screen_vertices), &screen_vertices, gl.STATIC_DRAW)
		gl.VertexArrayVertexBuffer(AppRenderer.screen_vao, 0, AppRenderer.screen_vbo, 0, 2*size_of(f32))
	}

	// Set texture ids
	gl.UseProgram(AppRenderer.shader)
	textures_ids := [8]i32{ 0, 1, 2, 3, 4, 5, 6, 7 }
	renderer_set_uniform_i32v(AppRenderer.shader, "u_texture", 8, raw_data(&textures_ids))
	gl.UseProgram(0)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

renderer_on_resize :: proc (window_width: i32, window_height: i32) {
	// Rebuild MSAA buffers
	{
		gl.BindFramebuffer(gl.FRAMEBUFFER, AppRenderer.msaa_fbo)
		gl.DeleteTextures(1, &AppRenderer.msaa_texture_color_buffer_multisampled)
		gl.DeleteRenderbuffers(1, &AppRenderer.msaa_rbo)
		gl.DeleteFramebuffers(1, &AppRenderer.msaa_fbo)

		gl.GenFramebuffers(1, &AppRenderer.msaa_fbo)
		gl.GenTextures(1, &AppRenderer.msaa_texture_color_buffer_multisampled)
		gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, AppRenderer.msaa_texture_color_buffer_multisampled)
		gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, MSAA_SAMPLES, gl.RGB, window_width, window_height, gl.TRUE)
		gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, 0)

		gl.GenRenderbuffers(1, &AppRenderer.msaa_rbo)
		gl.BindRenderbuffer(gl.RENDERBUFFER, AppRenderer.msaa_rbo)
		gl.RenderbufferStorageMultisample(gl.RENDERBUFFER, MSAA_SAMPLES, gl.DEPTH24_STENCIL8, window_width, window_height)
		gl.BindRenderbuffer(gl.RENDERBUFFER, 0)

		gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, AppRenderer.msaa_fbo)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D_MULTISAMPLE, AppRenderer.msaa_texture_color_buffer_multisampled, 0)
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, AppRenderer.msaa_rbo)

		status: u32 = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
		if status != gl.FRAMEBUFFER_COMPLETE {
			fmt.printf("MSAA FBO is not complete. Status: %v\n", status)
			assert(false)
		}
	}

	// Rebuild Post processing and screen buffers
	{
		gl.GenFramebuffers(1, &AppRenderer.post_processing_fbo)
		gl.GenTextures(1, &AppRenderer.screen_texture)
		gl.BindTexture(gl.TEXTURE_2D, AppRenderer.screen_texture)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, window_width, window_height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

		gl.BindFramebuffer(gl.FRAMEBUFFER, AppRenderer.post_processing_fbo)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, AppRenderer.screen_texture, 0)

		status: u32 = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
		if status!= gl.FRAMEBUFFER_COMPLETE {
			fmt.printf("Post processing FBO is not complete. Status: %v\n", status)
			assert(false)
		}

		gl.BindTexture(gl.TEXTURE_2D, 0)
		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	}
}

renderer_load_texture :: proc (path: string) -> u32 {
	exists := os.exists(path)
	if !exists {
		fmt.printf("Texture '%v' doesn't exist.\n", path)
		assert(false)
	}

	width, height, channels: i32
	stb_img.set_flip_vertically_on_load(1)
	data := stb_img.load(strings.clone_to_cstring(path), &width, &height, &channels, 0)
	defer stb_img.image_free(data)

	texture_id: u32
	gl.GenTextures(1, &texture_id)    
	gl.BindTexture(gl.TEXTURE_2D, texture_id)

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

	gl.BindTexture(gl.TEXTURE_2D, 0)

	texture_handle := u32(len(AppRenderer.textures))
	append(&AppRenderer.textures, texture_id)

	return texture_handle
}

renderer_load_color :: proc (r: f32, g: f32, b: f32, a: f32) -> u32 {
	texture_data := [4]u8{u8(255.0*r),u8(255.0*g),u8(255.0*b),u8(255.0*a)}

	texture_id: u32
	gl.GenTextures(1, &texture_id)
	gl.BindTexture(gl.TEXTURE_2D, texture_id)

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(texture_data[:]))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

	gl.BindTexture(gl.TEXTURE_2D, 0)

	texture_handle := u32(len(AppRenderer.textures))
	append(&AppRenderer.textures, texture_id)

	return texture_handle
}

renderer_begin_frame :: proc () {
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, AppRenderer.msaa_fbo)

	gl.ClearColor(0.0, 0.0, 0.0, 1.0)
  gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
  gl.Enable(gl.DEPTH_TEST)
}

renderer_end_frame :: proc (view: lm.mat4, projection: lm.mat4, window_width: i32, window_height: i32) {
	gl.UseProgram(AppRenderer.shader)
	model      := lm.identity(lm.mat4)
	view       := view
	projection := projection
	renderer_set_uniform_mat4fv(AppRenderer.shader, "u_model",      &model) // TODO(fz): Temporary. Model should come from whatever we're rendering
	renderer_set_uniform_mat4fv(AppRenderer.shader, "u_view",       &view)
	renderer_set_uniform_mat4fv(AppRenderer.shader, "u_projection", &projection)
	
	for i: u32 = 0; i < u32(len(AppRenderer.textures)); i += 1 {
		gl.ActiveTexture(gl.TEXTURE0 + i)
		gl.BindTexture(gl.TEXTURE_2D, AppRenderer.textures[i])
	}

	// Draw to MSAA FBO
	{
		// Draw Triangles
		gl.BindVertexArray(AppRenderer.triangles_vao)
		gl.NamedBufferSubData(AppRenderer.triangles_vbo, 0, len(AppRenderer.triangles_vertices) * 3 * size_of(Vertex), raw_data(AppRenderer.triangles_vertices))
		gl.NamedBufferSubData(AppRenderer.triangles_ebo, 0, len(AppRenderer.triangles_indices) * size_of(u32), raw_data(AppRenderer.triangles_indices))
		gl.DrawElements(gl.TRIANGLES, i32(len(AppRenderer.triangles_indices)), gl.UNSIGNED_INT, nil)

		// Draw lines
		gl.BindVertexArray(AppRenderer.lines_vao)
		gl.NamedBufferSubData(AppRenderer.lines_vbo, 0, len(AppRenderer.lines_vertices) * 3 * size_of(Vertex), raw_data(AppRenderer.lines_vertices))
		gl.DrawArrays(gl.LINES, 0, i32(len(AppRenderer.lines_vertices)) * 3)

		gl.BindVertexArray(0)
	}

	// Copy from MSAA FBO to Post Processing FBO
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, AppRenderer.msaa_fbo)
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, AppRenderer.post_processing_fbo)
	gl.BlitFramebuffer(0, 0, window_width, window_height, 0, 0, window_width, window_height, gl.COLOR_BUFFER_BIT, gl.NEAREST)

	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0)
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)
	
	gl.ClearColor(1.0, 1.0, 1.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.Disable(gl.DEPTH_TEST)

	gl.UseProgram(AppRenderer.screen_shader)
	gl.BindVertexArray(AppRenderer.screen_vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, AppRenderer.screen_texture)

	renderer_set_uniform_i32(AppRenderer.screen_shader, "u_window_width", window_width)
	renderer_set_uniform_i32(AppRenderer.screen_shader, "u_window_height", window_height)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	gl.UseProgram(0)
	gl.BindVertexArray(0)
	gl.BindTexture(gl.TEXTURE_2D, 0)
}

renderer_push_line :: proc (a_position: lm.vec3, b_position: lm.vec3, texture: u32) {
	a := Vertex { a_position, lm.vec4{1.0, 1.0, 1.0, 1.0}, lm.vec3{0.0, 0.0, 0.0}, lm.vec3{0.0, 0.0, 0.0}, texture}
	b := Vertex { b_position, lm.vec4{1.0, 1.0, 1.0, 1.0}, lm.vec3{1.0, 1.0, 0.0}, lm.vec3{0.0, 0.0, 0.0}, texture}
	append(&AppRenderer.lines_vertices, a)
	append(&AppRenderer.lines_vertices, b)
}

renderer_push_triangle :: proc (a: Vertex, b: Vertex, c: Vertex, texture: u32) {
	triangle_vertices := [3]Vertex { a, b, c }

	for triangle_vertex in triangle_vertices {
		exists := false
		for vertex, index in AppRenderer.triangles_vertices {
			if vertex == triangle_vertex {
				append(&AppRenderer.triangles_indices, u32(index))
				exists = true
				break
			}
		}
		if !exists {
			index := u32(len(AppRenderer.triangles_vertices))
			append(&AppRenderer.triangles_vertices, triangle_vertex)
			append(&AppRenderer.triangles_indices, index)
		}
	}
}

renderer_push_quad :: proc (quad: Quad, color: lm.vec4, texture: u32) {
	a := quad.point
	b := lm.vec3{quad.point.x + quad.width, quad.point.y, quad.point.z}
	c := lm.vec3{quad.point.x + quad.width, quad.point.y + quad.height, quad.point.z}
	d := lm.vec3{quad.point.x, quad.point.y + quad.height, quad.point.z}

	va := Vertex { a, color, lm.vec3{0.0, 0.0, 0.0}, lm.vec3{0.0, 0.0, 0.0}, texture}
	vb := Vertex { b, color, lm.vec3{1.0, 0.0, 0.0}, lm.vec3{0.0, 0.0, 0.0}, texture}
	vc := Vertex { c, color, lm.vec3{1.0, 1.0, 0.0}, lm.vec3{0.0, 0.0, 0.0}, texture}
	vd := Vertex { d, color, lm.vec3{0.0, 1.0, 0.0}, lm.vec3{0.0, 0.0, 0.0}, texture}

	renderer_push_triangle(va, vb, vc, texture)
	renderer_push_triangle(va, vc, vd, texture)
}

renderer_load_model :: proc { renderer_load_model_wavefront }

renderer_load_model_wavefront :: proc (obj_path: string, texture: u32) {
	stopwatch: time.Stopwatch
	time.stopwatch_start(&stopwatch)

	obj := parse_wavefront(obj_path)

	for face in obj.face {
		is_quad := obj.face_type == .Type_Quad
		
		vertices: [4]Vertex
		vertices_count := is_quad ? 3 : 4
		for i in 0..<vertices_count {
			indices := face[i]
			
			// Subtract one because Wavefront's indices start at 1.
			v, vt, vn: lm.vec3
			if indices[0] != 0 {
				position_index := indices[0] - 1
				v = obj.vertex[position_index]
			}
			if indices[1] != 0 {
				uvw_index := indices[1] - 1
				vt = obj.vertex_texture[uvw_index]
			}
			if indices[2] != 0 {
				normal_index := indices[2] - 1
				vn = obj.vertex_normal[normal_index]
			}

			vertices[i] = Vertex{ v , Color_White, vt, vn, texture }
		}
		renderer_push_triangle(vertices[0], vertices[1], vertices[2], texture)
		if is_quad {
			renderer_push_triangle(vertices[0], vertices[2], vertices[3], texture)
		}
	}

	time.stopwatch_stop(&stopwatch)
	duration := time.stopwatch_duration(stopwatch)
	fmt.printf("[renderer_load_model_wavefront] Time loading %v: %.4fms.\n", obj_path, time.duration_milliseconds(duration))
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