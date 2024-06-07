package odinner

import "base:runtime"

import "core:fmt"
import "core:math"
import "core:c"

import "vendor:glfw"
import gl "vendor:OpenGL"

Time: f32;

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

main :: proc() {

  glfw.SetErrorCallback(error_callback);

	if !glfw.Init() {
		fmt.eprintln("GLFW has failed to load.")
		return
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.RESIZABLE, 1)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(640, 480, "Cube", nil, nil)
	if window == nil {
		fmt.eprintln("GLFW has failed to load the window.")
		return
	}
	defer glfw.DestroyWindow(window)

	glfw.MakeContextCurrent(window)
	glfw.SwapInterval(1)
	glfw.SetKeyCallback(window, key_callback)
	glfw.SetFramebufferSizeCallback(window, size_callback)

	gl.load_up_to(3, 3, glfw.gl_set_proc_address) 

	success: i32
	shader_info_log: [512]u8

	vertex_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &VertexShaderSource, nil)
	gl.CompileShader(vertex_shader)
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
	if b32(success) == gl.FALSE {
		gl.GetShaderInfoLog(vertex_shader, 512, nil, &shader_info_log[0])
		fmt.printf("Error compiling vertex shader: %s", shader_info_log)
		return
	}

	fragment_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &FragmentShaderSource, nil)
	gl.CompileShader(fragment_shader)
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
	if b32(success) == gl.FALSE {
		gl.GetShaderInfoLog(fragment_shader, 512, nil, &shader_info_log[0])
		fmt.printf("Error compiling fragment shader: %s", shader_info_log)
		return
	}

	shader_program: u32 = gl.CreateProgram()
	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, fragment_shader)
	gl.LinkProgram(shader_program)


	vertices: []f32 = {
		-0.5, -0.5, 0.0,
		 0.5, -0.5, 0.0,
		 0.0,  0.5, 0.0,
	}

	for !glfw.WindowShouldClose(window) {
		Time = f32(glfw.GetTime());

		imported()

		gl.ClearColor(math.sin_f32(Time), math.sin_f32(Time), math.cos_f32(Time), 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}


error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.println(desc, code)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if key == glfw.KEY_ESCAPE {
		glfw.SetWindowShouldClose(window, true)
	}
}

size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	gl.Viewport(0, 0, width, height)
}
